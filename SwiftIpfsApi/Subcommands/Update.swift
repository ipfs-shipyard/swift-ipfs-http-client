//
//  Update.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details.

public class Update : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func check(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("update/check", completionHandler: completionHandler )
    }
    
    public func log(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("update/log", completionHandler: completionHandler )
    }
}
