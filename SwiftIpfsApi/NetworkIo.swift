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
    
    @available(*, deprecated, message: "it will be removed.  Please use 'send(urlRequest: payload: progress: completion:)' instead")
    func receiveFrom(_ source: String, completionHandler: @escaping (Data) throws -> Void) throws
    
    @available(*, deprecated, message: "it will be removed.  Please use 'send(urlRequest: payload: progress: completion:)' instead")
    func streamFrom(_ source: String, updateHandler: @escaping (Data, URLSessionDataTask) throws -> Bool, completionHandler: @escaping (AnyObject) throws -> Void) throws
    
    @available(*, deprecated, message: "it will be removed.  Please use 'send(urlRequest: payload: progress: completion:)' instead")
    func sendTo(_ target: String, content: Data, completionHandler: @escaping (Data) -> Void) throws

    /// If we want to send a bunch of location addressed content (eg.files)
    @available(*, deprecated, message: "it will be removed.  Please use 'send(urlRequest: payload: progress: completion:)' instead")
    func sendTo(_ target: String, content: [String], completionHandler: @escaping (Data) -> Void) throws
    
    
    
    /// New interface should cover all cases.
    /** If we want to 
        * Send data to the server in the url request, we set the payload and a multipart
        message will be created and sent. If the progress block is set it will get called.
        On completion the completion block is called with the final response from the server.
     
        * Receive data from the server in the url request, we set the payload to nil.
        The url request is sent and the resulting completion to contain the requested data.
        If the progress is set it will get called as appropriate. 
        (eg. if we send a continuous log request)
    **/
    func send(urlRequest: String, with payload: Data?, progress: ((Int)->Void)?, completion: @escaping (Data)->Void) throws
    
}
