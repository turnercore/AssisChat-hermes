//
//  ProFeature.swift
//  AssisChat
//
//  StoreKit removed for the Hermes personal fork.
//

import Foundation
import SwiftUI

class ProFeature: ObservableObject {
    @AppStorage(SharedUserDefaults.proKey, store: SharedUserDefaults.shared)
    private(set) var pro = true

    var showBadge: Bool { false }
    var largestPurchasedProProductName: String? { nil }

    init() {}

    func prepareAndRestore() {}
}
