//
//  NetworkIO.swift
//  SwiftIPFSApi
//
//  Created by Teo on 21/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//

import Foundation

protocol NetworkIO {
    
    static func get(sourceURL: String) throws -> [UInt8]

    static func post(targetURL: String) throws -> [UInt8]
    
}