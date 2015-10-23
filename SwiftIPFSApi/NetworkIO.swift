//
//  NetworkIO.swift
//  SwiftIPFSApi
//
//  Created by Teo on 21/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//

import Foundation

protocol NetworkIo {
    
    static func receiveFrom(source: String, completionHandler: (NSData) -> Void) throws

    static func sendTo(target: String, content: NSData, completionHandler: (NSData) -> Void) throws

    /// If we want to send a bunch of location addressed content (eg.files)
    static func sendTo(target: String, content: [String], completionHandler: (NSData) -> Void) throws
}