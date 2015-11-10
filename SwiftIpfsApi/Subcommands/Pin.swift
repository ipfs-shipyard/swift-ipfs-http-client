//
//  Pin.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash

/** Pinning an object will ensure a local copy is not garbage collected. */
public class Pin : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func add(hash: Multihash, completionHandler: ([Multihash]) -> Void) throws {
        
        let hashString = b58String(hash)
        try parent!.fetchDictionary("pin/add?stream-channels=true&arg=" + hashString) {
            (jsonDictionary: Dictionary) in
            
            guard let objects = jsonDictionary["Pinned"] as? [AnyObject] else {
                throw IpfsApiError.PinError("Pin.add error: No Pinned objects in JSON data.")
            }
            
            let multihashes = try objects.map { try fromB58String($0 as! String) }
            
            completionHandler(multihashes)
        }
    }
    
    public func ls(completionHandler: ([Multihash : AnyObject]) -> Void) throws {
        
        /// The default is .Recursive
        try self.ls(.Recursive) {
            (result: [String : AnyObject]) throws -> Void in
            
            ///turn the result into a [Multihash : AnyObject]
            var multihashes: [Multihash : AnyObject] = [:]
            for (k,v) in result {
                multihashes[try fromB58String(k)] = v
            }
            
            completionHandler(multihashes)
        }
    }
    
    public func ls(pinType: PinType, completionHandler: ([String : AnyObject]) throws -> Void) throws {
        
        try parent!.fetchDictionary("pin/ls?stream-channels=true&t=" + pinType.rawValue) {
            (jsonDictionary: Dictionary) in
            
            guard let objects = jsonDictionary["Keys"] as? [String : AnyObject] else {
                throw IpfsApiError.PinError("Pin.ls error: No Keys Dictionary in JSON data.")
            }
            
            try completionHandler(objects)
        }
    }
    
    public func rm(hash: Multihash, completionHandler: ([Multihash]) -> Void) throws {
        try self.rm(hash, recursive: true, completionHandler: completionHandler)
    }
    
    public func rm(hash: Multihash, recursive: Bool, completionHandler: ([Multihash]) -> Void) throws {
        
        let hashString = b58String(hash)
        try parent!.fetchDictionary("pin/rm?stream-channels=true&r=\(recursive)&arg=\(hashString)") {
            (jsonDictionary: Dictionary) in
            
            guard let objects = jsonDictionary["Pinned"] as? [AnyObject] else {
                throw IpfsApiError.PinError("Pin.rm error: No Pinned objects in JSON data.")
            }
            
            let multihashes = try objects.map { try fromB58String($0 as! String) }
            
            completionHandler(multihashes)
        }
    }
    
}