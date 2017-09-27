//
//  WHEGoogleRequestsHandler.swift
//  Whesit
//
//  Created by Admin on 25.07.17.
//  Copyright © 2017 Sergey Artemyev. All rights reserved.
//

import Foundation
import AFNetworking
import CoreData

let googleGeocodingAPIurl = "https://maps.googleapis.com/maps/api/geocode/json"
let googlePlacesAPIurl = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
private let key = "AIzaSyA7apkCJkSSmDj6Oaol8sZmHA_49251ziw"
let language = "en"

//google JSON respond fields
enum FieldNames: String {
    case description, place_id, terms, matched_substrings //placeAPIFields
    case formatted_address, address_components, geometry, location, lat, lng, viewport, northeast, southwest //geocodingAPIFields
}
//allows searching desired element in convenient way
extension NSDictionary {
    
    subscript(_ field: FieldNames) -> Any? {
        return self.object(forKey: field.rawValue)
    }
    subscript(_ fields: FieldNames...) -> Any? {
        var result = self
        var i = 0
        while let object = result.object(forKey: fields[i].rawValue) as? NSDictionary {
            result = object
            i += 1
        }
        return result.object(forKey: fields[i].rawValue)
    }
}

class GoogleRequestsHandler {
    
    struct GenericGoogleMapResponseObject: Sequence, IteratorProtocol {
        enum TypeOfResponse: String {
            case GooglePlaceAutocomplete = "predictions"
            case GoogleGeocode = "results"
        }
        init (_ json: NSDictionary, type: TypeOfResponse) {
            self.jsonObject = json
            self.googleAPItype = type
        }
        private var element = 0
        mutating func next() -> NSDictionary? {
            if count == 0 || element == count {
                return nil
            } else {
                defer {element += 1}
                return self.resultsArray[element]
            }
        }
        private let jsonObject: NSDictionary
        let googleAPItype: TypeOfResponse
        private var hasSomeInfo: Bool {
            switch jsonObject.object(forKey: "status") as? String {
            case .some("OK"):
                return true
            default:
                return false
            }
        }
        private var resultsArray: Array<NSDictionary> {
            return jsonObject.object(forKey: googleAPItype.rawValue) as! Array<NSDictionary>
        }
        var count: Int {
            guard hasSomeInfo else{return 0}
            return resultsArray.count
        }
        subscript(i: Int, field: FieldNames) -> Any? {
            guard hasSomeInfo else{return nil}
            let desc = (i < resultsArray.count) ? i : i - 1
            return resultsArray[desc].object(forKey: field.rawValue)
        }
    }
    
    let requestOperationManager: AFHTTPRequestOperationManager = AFHTTPRequestOperationManager.init(
        baseURL: URL.init(string: googlePlacesAPIurl))

    func findPlaces(_ address: String, aroundPoint: (Double,Double)?, inRadius: Double?, requestNumber: Int?, completion: @escaping (_ result: GenericGoogleMapResponseObject, _ requestNumber: Int?) -> ()) {
        
        var parameters = ["input": address,
                          "language": language,
                          "key": key]
        if let _location = aroundPoint {
            let location = String.init(format: "%f,%f", _location.0, _location.1)
            parameters.updateValue(location, forKey: "location")
            if let _radius = inRadius {
                let radius = String(_radius) 
                parameters.updateValue(radius, forKey: "radius")
            }
        }
        //print(parameters)
        self.requestOperationManager.get(
            googlePlacesAPIurl,
            parameters: parameters,
            success: { (operation, responseObject) in
                if let response = responseObject as? NSDictionary {
                    let places = GenericGoogleMapResponseObject.init(response, type: .GooglePlaceAutocomplete)
                    completion(places, requestNumber)
                }
        },
            failure: { (operation, error) in
        })
    }
    func geocode(_ place: String?, numberOfRequest: Int?, completion: @escaping (_ result: GenericGoogleMapResponseObject, _ numberOfRequest: Int?) -> ()) {
        switch place {
        case .none:
            break
        default:
            let parameters = ["address": place,
                              "key": key]
            self.requestOperationManager.get(
                googleGeocodingAPIurl,
                parameters: parameters,
                success: { (operation, responseObject) in
                    if let response = responseObject as? NSDictionary {
                        let geocodes = GenericGoogleMapResponseObject.init(response, type: .GoogleGeocode)
                        completion(geocodes, numberOfRequest)
                    }
                },
                failure: { (operation, error) in
                })
        }
    }
    
    func transmute(_ geocodes: GenericGoogleMapResponseObject, using moc: NSManagedObjectContext, fromRequest request: Requests?, requestNumber: Int?) -> Array<RespondsForRequest>? {
        if geocodes.googleAPItype != .GoogleGeocode{
            return nil
        } else if geocodes.count == 0{
            return nil
        } else {
            let _requestNumber = (requestNumber ?? 0) * 10
            let respondsSet = request?.responds as? NSMutableSet
            var i = 0
            var array: Array<RespondsForRequest> = Array()
            for geocode in geocodes{
                let geoObject = CoreDataHelper.insertRespond(in: moc)
                geoObject.responseNumber = Int16(_requestNumber + i)
                geoObject.formattedAddress = geocode[.formatted_address] as? String
                geoObject.centerLatitude = geocode[.geometry,.location,.lat] as! Double
                geoObject.centerLongitude = geocode[.geometry,.location,.lng] as! Double
                geoObject.northEastLatitude = geocode[.geometry,.viewport,.northeast,.lat] as! Double
                geoObject.northEastLongitude = geocode[.geometry,.viewport,.northeast,.lng] as! Double
                geoObject.southWestLatitude = geocode[.geometry,.viewport,.southwest,.lat] as! Double
                geoObject.southWestLongitude = geocode[.geometry,.viewport,.southwest,.lng] as! Double
                geoObject.imageURL = String.init(format: "https://maps.googleapis.com/maps/api/staticmap?center=%f,%f&size=%ix%i&visible=%f,%f&visible=%f,%f",
                                                 geoObject.centerLatitude,
                                                 geoObject.centerLongitude,
                                                 pictureSize,
                                                 pictureSize,
                                                 geoObject.northEastLatitude,
                                                 geoObject.northEastLongitude,
                                                 geoObject.southWestLatitude,
                                                 geoObject.southWestLongitude) + "&" + key
                geoObject.request = request
                i += 1
                array.append(geoObject)
                if respondsSet != nil {
                    respondsSet!.add(geoObject)
                }
            }
            request?.responds = respondsSet

            return array
        }
    }
}
