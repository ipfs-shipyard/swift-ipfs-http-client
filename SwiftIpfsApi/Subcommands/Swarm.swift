//
//  Swarm.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultiaddr

public class Swarm : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    /** peers lists the set of peers this node is connected to.
     The completionHandler is passed an array of Multiaddr that represent
     the peers.
     */
    public func peers(completionHandler: ([Multiaddr]) throws -> Void) throws {
        try parent!.fetchDictionary("swarm/peers?stream-channels=true") {
            (jsonDictionary: Dictionary) in
            
            var addresses: [Multiaddr] = []
            if let swarmPeers = jsonDictionary["Strings"] as? [String] {
                /// Make an array of Multiaddr from each peer in swarmPeers.
                addresses = try swarmPeers.map { try newMultiaddr($0) }
            }
            
            /// convert the data into a Multiaddr array and pass it to the handler
            try completionHandler(addresses)
        }
    }
    
    public func addrs(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("swarm/addrs?stream-channels=true") {
            (jsonDictionary: Dictionary) in
            
            guard let addrsData = jsonDictionary["Addrs"] as? [String : [String]] else {
                throw IpfsApiError.SwarmError("Swarm.addrs error: No Addrs key in JSON data.")
            }
            completionHandler(addrsData)
        }
    }
    public func connect(multiAddr: String, completionHandler: (String) -> Void) throws {
        try parent!.fetchDictionary("swarm/connect?arg="+multiAddr) {
            (jsonDictionary: Dictionary) in
            
            /// Ensure we've only got one string as a result.
            guard let result = jsonDictionary["Strings"] as? [String] where result.count == 1 else {
                throw IpfsApiError.SwarmError("Swarm.connect error: \(jsonDictionary["Message"] as? String)")
            }
            /// Consider returning the dictionary instead...
            completionHandler(result[0])
        }
    }
    
    public func disconnect(multiaddr: String, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("swarm/disconnect?arg=" + multiaddr) {
            (jsonDictionary: Dictionary) in
            completionHandler(jsonDictionary)
        }
    }
}