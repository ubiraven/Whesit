//
//  CoreDataHelper.swift
//  Whesit
//
//  Created by Admin on 11.07.17.
//  Copyright © 2017 Sergey Artemyev. All rights reserved.
//

import UIKit
import CoreData

class CoreDataHelper: NSObject {

    class func insertManagedObjectWith(className: String, in managedObjectContext: NSManagedObjectContext) -> Any {
        
        let managedObject = NSEntityDescription.insertNewObject(forEntityName: className, into: managedObjectContext)
        return managedObject
    }
    
    class func fetchEntitiesWith(className: String, in managedObjectContext: NSManagedObjectContext, with predicate: NSPredicate?) -> Array<Any> {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        let entityDescription = NSEntityDescription.entity(forEntityName: className, in: managedObjectContext)
        fetchRequest.entity = entityDescription
        if (predicate != nil) {
            fetchRequest.predicate = predicate
        }
        fetchRequest.returnsObjectsAsFaults = false
        
        if let items = try? managedObjectContext.fetch(fetchRequest) {
            return items
        } else {
            return Array()
        }
    }
    
    class func insertRequest(in moc: NSManagedObjectContext) -> Requests {
        return self.insertManagedObjectWith(className: "Requests", in: moc) as! Requests
    }
    class func insertRespond(in moc: NSManagedObjectContext) -> RespondsForRequest {
        return self.insertManagedObjectWith(className: "RespondsForRequest", in: moc) as! RespondsForRequest
    }
    class func fetchRequests(in moc: NSManagedObjectContext, with predicate: NSPredicate?) -> Array<Requests>? {
        return self.fetchEntitiesWith(className: "Requests", in: moc, with: predicate) as? Array<Requests>
    }
    class func save(_ responds: Array<RespondsForRequest>, forRequest: String, in moc: NSManagedObjectContext) -> Bool {
        
        var request: Requests
        let predicate = NSPredicate.init(format: "requestParameters like %@", argumentArray: [forRequest])
        
        if (self.fetchRequests(in: moc, with: predicate)?.count)! > 0 {
            /*
            request = existedEntity.max(by: { (elem1, elem2) -> Bool in
                let order = elem1.dateOfRequest?.compare(elem2.dateOfRequest as! Date)
                switch order! {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: return true
                }
            })!
            */
            var existedEntity = self.fetchRequests(in: moc, with: predicate)!
            request = existedEntity[0]
            var existedResponds = Array<RespondsForRequest>()
            if let array = request.responds?.allObjects as? Array<RespondsForRequest> {
                existedResponds.append(contentsOf: array)
            }
            for respond in responds {
                existedResponds.forEach({ (elem) in
                    if elem.formattedAddress == respond.formattedAddress {
                        existedResponds.remove(at: existedResponds.index(of: elem)!)
                        moc.delete(elem)
                    }
                })
                existedResponds.append(respond)
            }
           
            request.responds = NSSet(array: existedResponds)
            request.dateOfRequest = NSDate.init()
        } else {
            request = self.insertRequest(in: moc)
            request.requestParameters = forRequest
            request.dateOfRequest = NSDate.init()
            request.responds = NSSet(array: responds)
        }
        
        if (try? moc.save()) != nil {
            return true
        } else {
            return false
        }
    
    }
}
