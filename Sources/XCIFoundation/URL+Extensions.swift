//
//  File.swift
//  
//
//  Created by Gunnar Herzog on 31.10.23.
//

import Foundation

public extension URL {
    var isReachable: Bool {
        (try? checkResourceIsReachable()) == true
    }
}
