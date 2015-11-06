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
    
    func receiveFrom(source: String, completionHandler: (NSData) throws -> Void) throws

    func streamFrom(source: String, updateHandler: (NSData, NSURLSessionDataTask) throws -> Void, completionHandler: (AnyObject) throws -> Void) throws
    
    func sendTo(target: String, content: NSData, completionHandler: (NSData) -> Void) throws

    /// If we want to send a bunch of location addressed content (eg.files)
    func sendTo(target: String, content: [String], completionHandler: (NSData) -> Void) throws
}