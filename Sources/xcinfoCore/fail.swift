//
//  File.swift
//  
//
//  Created by Gunnar Herzog on 02.04.23.
//

import Foundation

func fail(statusCode: Int, errorMessage: String? = nil) -> Never {
    if let errorMessage = errorMessage {
        print(errorMessage)
    }
    exit(Int32(statusCode))
}
