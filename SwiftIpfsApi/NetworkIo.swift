//
//  NetworkIo.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 21/10/15.
//
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation

public protocol NetworkIo {
    
    func receiveFrom(_ source: String, completionHandler: (Data) throws -> Void) throws

    func streamFrom(_ source: String, updateHandler: (Data, URLSessionDataTask) throws -> Bool, completionHandler: (AnyObject) throws -> Void) throws
    
    func sendTo(_ target: String, content: Data, completionHandler: (Data) -> Void) throws

    /// If we want to send a bunch of location addressed content (eg.files)
    func sendTo(_ target: String, content: [String], completionHandler: (Data) -> Void) throws
}
