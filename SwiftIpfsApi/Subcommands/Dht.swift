//
//  Dht.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash
import SwiftMultiaddr

public class Dht : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func findProvs(hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/findprovs?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func query(address: Multiaddr, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/query?arg=" + address.string() , completionHandler: completionHandler)
    }
    
    public func findpeer(address: Multiaddr, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/findpeer?arg=" + address.string() , completionHandler: completionHandler)
    }
    
    public func get(hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/get?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func put(key: String, value: String, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/put?arg=\(key)&arg=\(value)", completionHandler: completionHandler)
    }
}