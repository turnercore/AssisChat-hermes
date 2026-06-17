//
//  HermesModelCatalog.swift
//  AssisChat
//
//

import Foundation

enum HermesModelCatalog {
    static func available(discovered: [String], active: [String], configured: String?) -> [String] {
        let values = discovered + active + [configured].compactMap { $0 }
        var seen = Set<String>()
        let unique = values
            .compactMap { $0.nilIfBlank }
            .filter { value in
                guard !seen.contains(value) else { return false }
                seen.insert(value)
                return true
            }
            .sorted()

        return unique.isEmpty ? [Chat.HermesModel.default.rawValue] : unique
    }
}
