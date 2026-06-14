//
//  Dictionary+Extensions.swift
//  AssisChat
//
//

import Foundation
import CoreData


// MARK: - CoreData
extension Dictionary where Key == AnyHashable {
    func value<T>(for key: NSManagedObjectContext.NotificationKey) -> T? {
        return self[key.rawValue] as? T
    }
}

