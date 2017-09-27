//
//  Requests+CoreDataProperties.swift
//  Whesit
//
//  Created by Admin on 11.07.17.
//  Copyright © 2017 Sergey Artemyev. All rights reserved.
//

import Foundation
import CoreData


extension Requests {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Requests> {
        return NSFetchRequest<Requests>(entityName: "Requests");
    }

    @NSManaged public var dateOfRequest: NSDate?
    @NSManaged public var requestParameters: String?
    @NSManaged public var responds: NSSet?

}

// MARK: Generated accessors for responds
extension Requests {

    @objc(addRespondsObject:)
    @NSManaged public func addToResponds(_ value: RespondsForRequest)

    @objc(removeRespondsObject:)
    @NSManaged public func removeFromResponds(_ value: RespondsForRequest)

    @objc(addResponds:)
    @NSManaged public func addToResponds(_ values: NSSet)

    @objc(removeResponds:)
    @NSManaged public func removeFromResponds(_ values: NSSet)

}
