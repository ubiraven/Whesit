//
//  RespondsForRequest+CoreDataProperties.swift
//  Whesit
//
//  Created by Admin on 11.07.17.
//  Copyright © 2017 Sergey Artemyev. All rights reserved.
//

import Foundation
import CoreData


extension RespondsForRequest {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RespondsForRequest> {
        return NSFetchRequest<RespondsForRequest>(entityName: "RespondsForRequest");
    }

    @NSManaged public var centerLatitude: Double
    @NSManaged public var centerLongitude: Double
    @NSManaged public var formattedAddress: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var northEastLatitude: Double
    @NSManaged public var northEastLongitude: Double
    @NSManaged public var responseNumber: Int16
    @NSManaged public var southWestLatitude: Double
    @NSManaged public var southWestLongitude: Double
    @NSManaged public var request: Requests?

}
