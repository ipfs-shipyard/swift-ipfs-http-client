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
    
    func receiveFrom(_ source: String, completionHandler: @escaping (Data) throws -> Void) throws

    func streamFrom(_ source: String, updateHandler: @escaping (Data, URLSessionDataTask) throws -> Bool, completionHandler: @escaping (AnyObject) throws -> Void) throws
    
    func sendTo(_ target: String, content: Data, completionHandler: @escaping (Data) -> Void) throws

    /// If we want to send location addressed content
    func sendTo(_ target: String, filePath: String, completionHandler: @escaping (Data) -> Void) throws
}
