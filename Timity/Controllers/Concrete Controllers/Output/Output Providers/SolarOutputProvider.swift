//
//  SolarOutputProvider.swift
//  OutputTableView
//
//  Created by Andreas Link on 3/13/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import UIKit
import Solar
import CoreLocation

class SolarOutputProvider: OutputProvider {

    ///Private properties
    var location:CLLocationCoordinate2D?{
        didSet{
            computeSections()
        }
    }
    
    ///Localized Strings
    let sunrise = NSLocalizedString("output_solar_calculator_details_sunrise",
                                           comment: "String preceding the sunrise date of the solar calculator.")
    let sunset = NSLocalizedString("output_solar_calculator_details_sunset",
                                          comment: "String preceding the sunset of the solar calculator.")
    let daylight = NSLocalizedString("output_solar_calculator_details_daylight",
                                   comment: "String preceding the daylight of the solar calculator.")
    
    let officialDetailsHeader = NSLocalizedString("output_solar_calculator_official_details_header",
                                                  comment: "Header of the official section in the output of the solar calculator.")
    let officialDetailsFooter = NSLocalizedString("output_solar_calculator_official_details_footer",
                                                  comment: "Footer of the official section in the output of the solar calculator.")
    
    let civilDetailsHeader = NSLocalizedString("output_solar_calculator_civil_details_header",
                                               comment: "Header of the civil section in the output of the solar calculator.")
    let civilDetailsFooter = NSLocalizedString("output_solar_calculator_civil_details_footer",
                                               comment: "Footer of the civil section in the output of the solar calculator.")
    
    let nauticalDetailsHeader = NSLocalizedString("output_solar_calculator_nautical_details_header",
                                                  comment: "Header of the nautical section in the output of the solar calculator.")
    let nauticalDetailsFooter = NSLocalizedString("output_solar_calculator_nautical_details_footer",
                                                  comment: "Footer of the nautical section in the output of the solar calculator.")
    
    let astronomicalDetailsHeader = NSLocalizedString("output_solar_calculator_astronomical_details_header",
                                                      comment: "Header of the astronomical section in the output of the solar calculator.")
    let astronomicalDetailsFooter = NSLocalizedString("output_solar_calculator_astronomical_details_footer",
                                                      comment: "Footer of the astronomical section in the output of the solar calculator.")
    
    override func start() {
        ///Start Location Updates
        if !LocationManager.shared.delegates.containsDelegate(self){
            LocationManager.shared.delegates.addDelegate(self)
        }
        
        LocationManager.shared.startLocationUpdates()
    }
    
    override func stop() {
        
        ///Stop Location Updates
        LocationManager.shared.stopLocationUpdates()
        LocationManager.shared.delegates.removeDelegate(self)
    }
    
    override func computeSections() {
        guard let location = location else {return}

        ///Obtain sunrise and sunset
        let solar = Solar(for: Date(), coordinate: location)
        
        ///Obtain official sunrise/sunset data
        var officialSunriseDateString = ""
        if let sunrise = solar?.sunrise{
            officialSunriseDateString = Formatter.format(date: sunrise, style: .time)
        }
        var officialSunsetDateString = ""
        if let sunset = solar?.sunset{
            officialSunsetDateString = Formatter.format(date: sunset, style: .time)
        }
        var officialDaylightString = ""
        if
            let sunrise = solar?.sunrise,
            let sunset = solar?.sunset{
            officialDaylightString = Formatter.format(timeInterval: sunset.timeIntervalSince(sunrise), style: .abbreviated) ?? ""
        }
        
        ///Obtain civil sunrise/sunset data
        var civilSunriseDateString = ""
        if let civilSunrise = solar?.civilSunrise{
            civilSunriseDateString = Formatter.format(date: civilSunrise, style: .time)
        }
        var civilSunsetDateString = ""
        if let civilSunset = solar?.civilSunset{
            civilSunsetDateString = Formatter.format(date: civilSunset, style: .time)
        }
        var civilDaylightString = ""
        if
            let sunrise = solar?.civilSunrise,
            let sunset = solar?.civilSunset{
            civilDaylightString = Formatter.format(timeInterval: sunset.timeIntervalSince(sunrise), style: .abbreviated) ?? ""
        }
        
        ///Obtain nautical sunrise/sunset data
        var nauticalSunriseDateString = ""
        if let nauticalSunrise = solar?.nauticalSunrise{
            nauticalSunriseDateString = Formatter.format(date: nauticalSunrise, style: .time)
        }
        var nauticalSunsetDateString = ""
        if let nauticalSunset = solar?.nauticalSunset{
            nauticalSunsetDateString = Formatter.format(date: nauticalSunset, style: .time)
        }
        var nauticalDaylightString = ""
        if
            let sunrise = solar?.nauticalSunrise,
            let sunset = solar?.nauticalSunset{
            nauticalDaylightString = Formatter.format(timeInterval: sunset.timeIntervalSince(sunrise), style: .abbreviated) ?? ""
        }
        
        ///Obtain astronomical sunrise/sunset data
        var astronomicalSunriseDateString = ""
        if let astronomicalSunrise = solar?.astronomicalSunrise{
            astronomicalSunriseDateString = Formatter.format(date: astronomicalSunrise, style: .time)
        }
        var astronomicalSunsetDateString = ""
        if let astronomicalSunset = solar?.astronomicalSunset{
            astronomicalSunsetDateString = Formatter.format(date: astronomicalSunset, style: .time)
        }
        var astronomicalDaylightString = ""
        if
            let sunrise = solar?.astronomicalSunrise,
            let sunset = solar?.astronomicalSunset{
            astronomicalDaylightString = Formatter.format(timeInterval: sunset.timeIntervalSince(sunrise), style: .abbreviated) ?? ""
        }
        
        ///Section: Official Sunrise and Sunset
        let sunriseOfficialRow = Row(id: ID().officialSolar().sunrise().value,
                                 value: LeftRightValue(leftText: sunrise,
                                                       rightText: officialSunriseDateString)
        )
        
        let sunsetOfficialRow = Row(id: ID().officialSolar().sunset().value,
                                     value: LeftRightValue(leftText: sunset,
                                                           rightText: officialSunsetDateString)
        )
        
        let daylightOfficialRow = Row(id: ID().officialSolar().daylight().value,
                                    value: LeftRightValue(leftText: daylight,
                                                          rightText: officialDaylightString)
        )
        
        let officialSection = Section(id: ID().officialSolar().value,
                                       header: officialDetailsHeader,
                                       footer: officialDetailsFooter,
                                       rows: [sunriseOfficialRow, sunsetOfficialRow, daylightOfficialRow])
        
        ///Section: Civil Sunrise and Sunset
        let sunriseCivilRow = Row(id: ID().civilSolar().sunrise().value,
                                     value: LeftRightValue(leftText: sunrise,
                                                           rightText: civilSunriseDateString)
        )
        
        let sunsetCivilRow = Row(id: ID().civilSolar().sunset().value,
                                    value: LeftRightValue(leftText: sunset,
                                                          rightText: civilSunsetDateString)
        )
        
        let daylightCivilRow = Row(id: ID().civilSolar().daylight().value,
                                      value: LeftRightValue(leftText: daylight,
                                                            rightText: civilDaylightString)
        )
        
        let civilSection = Section(id: ID().civilSolar().value,
                                      header: civilDetailsHeader,
                                      footer: civilDetailsFooter,
                                      rows: [sunriseCivilRow, sunsetCivilRow, daylightCivilRow])
        
        ///Section: Nautical Sunrise and Sunset
        let sunriseNauticalRow = Row(id: ID().nauticalSolar().sunrise().value,
                                  value: LeftRightValue(leftText: sunrise,
                                                        rightText: nauticalSunriseDateString)
        )
        
        let sunsetNauticalRow = Row(id: ID().nauticalSolar().sunset().value,
                                 value: LeftRightValue(leftText: sunset,
                                                       rightText: nauticalSunsetDateString)
        )
        
        let daylightNauticalRow = Row(id: ID().nauticalSolar().daylight().value,
                                   value: LeftRightValue(leftText: daylight,
                                                         rightText: nauticalDaylightString)
        )
        
        let nauticalSection = Section(id: ID().nauticalSolar().value,
                                   header: nauticalDetailsHeader,
                                   footer: nauticalDetailsFooter,
                                   rows: [sunriseNauticalRow, sunsetNauticalRow, daylightNauticalRow])
        
        ///Section: Astronomical Sunrise and Sunset
        let sunriseAstronomicalRow = Row(id: ID().astronomicalSolar().sunrise().value,
                                     value: LeftRightValue(leftText: sunrise,
                                                           rightText: astronomicalSunriseDateString)
        )
        
        let sunsetAstronomicalRow = Row(id: ID().astronomicalSolar().sunset().value,
                                    value: LeftRightValue(leftText: sunset,
                                                          rightText: astronomicalSunsetDateString)
        )
        
        let daylightAstronomicalRow = Row(id: ID().astronomicalSolar().daylight().value,
                                      value: LeftRightValue(leftText: daylight,
                                                            rightText: astronomicalDaylightString)
        )
        
        let astronomicalSection = Section(id: ID().astronomicalSolar().value,
                                      header: astronomicalDetailsHeader,
                                      footer: astronomicalDetailsFooter,
                                      rows: [sunriseAstronomicalRow, sunsetAstronomicalRow, daylightAstronomicalRow])
        
        ///Notify delegate about new sections
        delegate?.sectionsDidUpdate([officialSection,
                                     civilSection,
                                     nauticalSection,
                                     astronomicalSection])
    }
    
    ///EmptyDataBackgroundView
    override func dataForEmptyBackgroundView() -> (title: String, message: String, image: UIImage?)? {
        
        let title = NSLocalizedString("output_solar_calculator_location_not_yet_determined_title",
                                      comment: "Title indicating that the location is not yet determined.")
        let message = NSLocalizedString("output_solar_calculator_location_not_yet_determined_message",
                                        comment: "Message indicating that the location is not yet determined.")
        let logo = UIImage(named:"location")
        
        return (title, message, logo)
    }
}

extension SolarOutputProvider:LocationManagerDelegate{
    func locationDidUpdateTo(_ location:CLLocationCoordinate2D){
        self.location = location
    }
    func locationCouldNotBeDetermined(){

    }
}
