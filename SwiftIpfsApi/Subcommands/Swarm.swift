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
    
    /** Lists the set of peers this node is connected to.
        The completionHandler is passed an array of Multiaddr that represent the peers.
     */
    public func peers(_ completionHandler: @escaping (Result<[Multiaddr], Error>) -> Void) {
        parent!.fetchJson("swarm/peers?stream-channels=true") { result in
            let transformation = result.flatMap { json -> Result<[Multiaddr], Error> in
                guard let swarmPeers = json.object?[IpfsCmdString.Peers.rawValue]?.array else {
                    return .success([])
                }

                do {
                    // Make an array of Multiaddr from each peer in swarmPeers.
                    let addresses: [Multiaddr] = try swarmPeers.map {
                        guard let peer = $0.object?["Addr"]?.string else { throw IpfsApiError.nilData }

                        // Broken until multiaddr can deal with p2p-circuit multiaddr
                        return try newMultiaddr(peer)
                    }
                    return .success(addresses)
                } catch {
                    return .failure(error)
                }
            }
            completionHandler(transformation)
        }
    }
    
    /** lists all addresses this node is aware of. */
    public func addrs(_ completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("swarm/addrs?stream-channels=true") { result in
            switch result {
            case .success(let json):
                guard let addrsData = json.object?[IpfsCmdString.Addrs.rawValue] else {
                    return completionHandler(.failure(IpfsApiError.swarmError("Swarm.addrs error: No Addrs key in JSON data.")))
                }

                completionHandler(.success(addrsData))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    /** opens a new direct connection to a peer address. */
    public func connect(_ multiaddr: String, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("swarm/connect?arg=" + multiaddr, completionHandler: completionHandler)
    }
    
    public func disconnect(_ multiaddr: String, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("swarm/disconnect?arg=" + multiaddr, completionHandler: completionHandler)
    }
}
