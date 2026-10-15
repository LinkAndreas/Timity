import SwiftUI
import Vision

/// Where in a photo its subject is, so cropping keeps it in view: the faces if there
/// are any, else what draws the eye, else the middle. Any photo works, a portrait
/// or a landscape alike.
enum PhotoFocus {
    private static var cache: [Int: UnitPoint] = [:]

    static func point(for data: Data) async -> UnitPoint {
        let key = data.hashValue
        if let cached = cache[key] { return cached }
        let point = await detect(in: data)
        cache[key] = point
        return point
    }

    @concurrent
    private static func detect(in data: Data) async -> UnitPoint {
        guard let image = ImageProcessing.thumbnail(from: data, maxPixelSize: 512) else { return .center }
        let handler = VNImageRequestHandler(cgImage: image)
        let faces = VNDetectFaceRectanglesRequest()
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([faces, saliency])

        let faceBoxes = faces.results?.map(\.boundingBox) ?? []
        let salientBoxes = saliency.results?.first?.salientObjects?.map(\.boundingBox) ?? []
        let boxes = faceBoxes.isEmpty ? salientBoxes : faceBoxes
        guard let first = boxes.first else { return .center }
        let box = boxes.dropFirst().reduce(first) { $0.union($1) }
        // Vision measures from the bottom left; SwiftUI from the top left.
        return UnitPoint(x: box.midX, y: 1 - box.midY)
    }
}

/// A photo filling its frame, cropped around `focus` rather than the middle, as far
/// as the photo reaches.
struct FocusedPhoto: View {
    let image: CGImage
    var focus: UnitPoint = .center

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.size
            let pixels = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
            let scale = max(frame.width / max(pixels.width, 1), frame.height / max(pixels.height, 1))
            let shown = CGSize(width: pixels.width * scale, height: pixels.height * scale)
            let x = min(0, max(frame.width - shown.width, frame.width / 2 - focus.x * shown.width))
            let y = min(0, max(frame.height - shown.height, frame.height / 2 - focus.y * shown.height))
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: shown.width, height: shown.height)
                .offset(x: x, y: y)
        }
        .clipped()
        .animation(.smooth, value: focus)
    }
}
