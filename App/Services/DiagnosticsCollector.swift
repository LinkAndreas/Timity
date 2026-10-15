import CloudKit
import Foundation
import MetricKit

/// Crash, hang, CPU, disk-write and launch diagnostics from MetricKit — iOS's own —
/// kept on this device and, when the user allows it, sent to the developer's iCloud
/// container. No third-party service sees them; they hold no name and no events.
nonisolated final class DiagnosticsCollector: NSObject, MXMetricManagerSubscriber, Sendable {
    /// Reports waiting to be sent, newest last.
    let folder: URL
    private let isSharingAllowed: @Sendable () -> Bool
    private let uploader: CloudKitDiagnosticsUploader

    /// The most reports kept while sharing is off or iCloud can't be reached.
    private static let limit = 20

    init(folder: URL, containerIdentifier: String, isSharingAllowed: @escaping @Sendable () -> Bool) {
        self.folder = folder
        self.isSharingAllowed = isSharingAllowed
        uploader = CloudKitDiagnosticsUploader(containerIdentifier: containerIdentifier)
        super.init()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Starts receiving reports; iOS delivers those since the last launch soon after.
    func start() {
        MXMetricManager.shared.add(self)
        keep(MXMetricManager.shared.pastDiagnosticPayloads)
        Task { await sendPending() }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        keep(payloads)
        Task { await sendPending() }
    }

    /// Sends what's waiting, when the user allows it; what can't be sent stays for next time.
    func sendPending() async {
        guard isSharingAllowed() else { return }
        for file in pendingFiles() {
            do {
                try await uploader.upload(file)
                try? FileManager.default.removeItem(at: file)
            } catch {
                logger.info("Couldn't send a diagnostics report: \(error)")
                return
            }
        }
    }

    /// How many reports are waiting.
    var pendingCount: Int { pendingFiles().count }

    private func keep(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let kinds = Self.kinds(of: payload)
            guard !kinds.isEmpty else { continue }
            let stamp = Int(payload.timeStampEnd.timeIntervalSince1970)
            let name = "\(stamp)-\(kinds.joined(separator: "+")).json"
            let file = folder.appending(path: name)
            guard !FileManager.default.fileExists(atPath: file.path) else { continue }
            try? payload.jsonRepresentation().write(to: file)
        }
        // The oldest go first once there are too many.
        for file in pendingFiles().dropLast(Self.limit) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func pendingFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// "crash", "hang" and so on, for what the payload holds.
    static func kinds(of payload: MXDiagnosticPayload) -> [String] {
        var kinds: [String] = []
        if !(payload.crashDiagnostics ?? []).isEmpty { kinds.append("crash") }
        if !(payload.hangDiagnostics ?? []).isEmpty { kinds.append("hang") }
        if !(payload.cpuExceptionDiagnostics ?? []).isEmpty { kinds.append("cpu") }
        if !(payload.diskWriteExceptionDiagnostics ?? []).isEmpty { kinds.append("disk") }
        if !(payload.appLaunchDiagnostics ?? []).isEmpty { kinds.append("launch") }
        return kinds
    }
}

/// Saves a report as a `DiagnosticReport` record in the container's public database,
/// which only the developer can read (see "Crash and hang reports" in Docs/Setup.md).
nonisolated struct CloudKitDiagnosticsUploader: Sendable {
    static let recordType = "DiagnosticReport"

    let containerIdentifier: String

    func upload(_ file: URL) async throws {
        let record = CKRecord(recordType: Self.recordType)
        let name = file.deletingPathExtension().lastPathComponent
        record["kind"] = String(name.split(separator: "-").dropFirst().joined(separator: "-"))
        record["appVersion"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        record["build"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        record["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        record["device"] = Self.deviceModel
        record["payload"] = CKAsset(fileURL: file)
        _ = try await CKContainer(identifier: containerIdentifier).publicCloudDatabase.save(record)
    }

    /// "iPhone18,1".
    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
