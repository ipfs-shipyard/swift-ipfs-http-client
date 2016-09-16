//
//  Repo.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

public class Repo : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    /** gc is a plumbing command that will sweep the local set of stored objects
     and remove ones that are not pinned in order to reclaim hard disk space. */
    public func gc(_ completionHandler: @escaping (JsonType) -> Void) throws {
        try parent!.fetchJson("repo/gc", completionHandler: completionHandler)
    }
//    public func gc(completionHandler: ([[String : AnyObject]]) -> Void) throws {
//        try parent!.fetchData("repo/gc") {
//            (rawJson: NSData) in
//            
//            /// Check for streamed JSON format and wrap & separate.
//            let data = fixStreamJson(rawJson)
//            
//            guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? [[String : AnyObject]] else { throw IpfsApiError.JsonSerializationFailed
//            }
//            
//            completionHandler(json)
//        }
//    }
}
