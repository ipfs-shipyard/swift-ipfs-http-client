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
    
    /** FindProviders will return a list of peers who are able to provide the value requested. */
    public func findProvs(_ hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws {
        try parent!.fetchJson("dht/findprovs?arg=" + b58String(hash), completionHandler: completionHandler)
    }
   
    /** Run a 'findClosestPeers' query through the DHT */
    public func query(_ hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws {
        try parent!.fetchJson("dht/query?arg=" + b58String(hash) , completionHandler: completionHandler)
    }
    
    /** Run a 'FindPeer' query through the DHT */
    public func findpeer(_ hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws {
        try parent!.fetchJson("dht/findpeer?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    /** Will return the value stored in the dht at the given key */
    public func get(_ hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws {
        try parent!.fetchJson("dht/get?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    /** Will store the given key value pair in the dht. */
    public func put(_ key: String, value: String, completionHandler: @escaping (JsonType) -> Void) throws {
        try parent!.fetchJson("dht/put?arg=\(key)&arg=\(value)", completionHandler: completionHandler)
    }
}
