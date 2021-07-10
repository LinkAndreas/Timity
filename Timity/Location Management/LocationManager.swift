//
//  LocationManager.swift
//  Timity
//
//  Created by Andreas Link on 2/20/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import CoreLocation
import MulticastDelegateSwift

protocol LocationManagerDelegate{
    func locationDidUpdateTo(_ location:CLLocationCoordinate2D)
    func locationCouldNotBeDetermined()
}

extension LocationManagerDelegate{
    func locationDidUpdateTo(_ location:CLLocationCoordinate2D){}
    func locationCouldNotBeDetermined(){}
}

class LocationManager:NSObject {
    ///Singleton
    static var shared = LocationManager()
    var delegates = MulticastDelegate<LocationManagerDelegate>()
    
    ///Private Properties
    private var lm = CLLocationManager()
    
    override init() {
        super.init()
    }
    
    func isReadyForLocationUpdates()->Bool{
        var isReady = true
        if !CLLocationManager.locationServicesEnabled() { isReady = false; locationServicesDisabled() }
        let status = CLLocationManager.authorizationStatus()
        if status == .denied || status == .restricted { isReady = false; accessDenied() }
        return isReady
    }
    
    //MARK: Lifecyle
    func startLocationUpdates(){
        if CLLocationManager.locationServicesEnabled() {
            switch(CLLocationManager.authorizationStatus()) {
            case .restricted, .denied:
                accessDenied()

            case .authorizedAlways, .authorizedWhenInUse:
                accessGranted()

            case .notDetermined:
                accessNotDetermined()

            @unknown default:
                break
            }
        } else {
            locationServicesDisabled()
        }
    }
    
    func stopLocationUpdates(){
        lm.stopUpdatingLocation()
    }
    
    func accessNotDetermined(){
        lm.delegate = self
        lm.requestWhenInUseAuthorization()
    }
    
    func accessGranted(){
        lm.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        lm.delegate = self
        
        ///Check whether the last location was stored and use it to update the UI immediately
        if let lastLocation = Settings.shared.lastLocation{
            locationDidUpdateTo(lastLocation)
        }
        lm.startUpdatingLocation()
    }
    
    func locationServicesDisabled(){
        ///Generate localized strings
        let locationServicesDisabledTitle = NSLocalizedString("alert_location_manager_location_services_disabled_title",
                                                              comment: "Alert title indicating that location services are disabled in the location manager.")
        let locationServicesDisabledMessage = NSLocalizedString("alert_location_manager_location_services_disabled_message",
                                                              comment: "Alert message indicating that location services are disabled in the location manager.")
        
        Settings.shared.showAlertWith(title: locationServicesDisabledTitle,
                                      message: locationServicesDisabledMessage)
    }
    
    func accessDenied(){
        ///Stop searching for location
        lm.stopUpdatingLocation()
        
        ///Generate localized strings
        let accessDeniedTitle = NSLocalizedString("alert_location_manager_access_denied_title",
                                                  comment: "Alert title indicating that the access to location services is denied in the location manager.")
        let accessDeniedMessage = NSLocalizedString("alert_location_manager_access_denied_message",
                                                    comment: "Alert message indicating that the access to location services is denied in the location manager.")
        
        Settings.shared.showAlertWith(title: accessDeniedTitle,
                                      message: accessDeniedMessage)
    }
    
    func locationUnknown(){
        ///Generate localized strings
        let locationUnknownTitle = NSLocalizedString("alert_location_manager_location_unknown_title",
                                                  comment: "Alert title indicating that the current location is unknown in the location manager.")
        let locationUnknownMessage = NSLocalizedString("alert_location_manager_location_unknown_message",
                                                    comment: "Alert message indicating that the current location is unknown in the location manager.")
        
        Settings.shared.showAlertWith(title: locationUnknownTitle,
                                      message: locationUnknownMessage)
        
        ///Notify delegates about changes
        delegates |> {
            delegate in
            delegate.locationCouldNotBeDetermined()
        }
    }
    
    func locationDidUpdateTo(_ location:CLLocationCoordinate2D){
        ///Remember last location
        Settings.shared.lastLocation = location
        
        ///Notify delegates about changes
        delegates |> {
            delegate in
            delegate.locationDidUpdateTo(location)
        }
    }
}

extension LocationManager:CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            accessGranted()

        case .restricted, .denied:
            accessDenied()

        case .notDetermined:
            accessNotDetermined()

        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let recentLocation = locations.last else {return}
        locationDidUpdateTo(recentLocation.coordinate)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let error = error as? CLError else { return }
        if error.code == CLError.denied{
            accessDenied()
        }else if error.code == CLError.locationUnknown{
            if Settings.shared.lastLocation == nil{
                locationUnknown()
            }
        }
    }
}
