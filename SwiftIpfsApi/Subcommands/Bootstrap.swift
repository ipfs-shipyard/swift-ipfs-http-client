//
//  Bootstrap.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultiaddr

/**
 SECURITY WARNING:
 
 The bootstrap command manipulates the "bootstrap list", which contains
 the addresses of bootstrap nodes. These are the *trusted peers* from
 which to learn about other peers in the network. Only edit this list
 if you understand the risks of adding or removing nodes from this list.
 */
public class Bootstrap : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func list(_ completionHandler: @escaping (Result<[Multiaddr], Error>) -> Void) {
        fetchPeers("bootstrap/", completionHandler: completionHandler)
    }
    
    public func add(_ addresses: [Multiaddr], completionHandler: @escaping (Result<[Multiaddr], Error>) -> Void) {
        do {
            let multiaddresses = try addresses.map { try $0.string() }
            let request = "bootstrap/add?" + buildArgString(multiaddresses)

            fetchPeers(request, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    public func rm(_ addresses: [Multiaddr], completionHandler: @escaping (Result<[Multiaddr], Error>) -> Void) {
        rm(addresses, all: false, completionHandler: completionHandler)
    }
    
    public func rm(_ addresses: [Multiaddr], all: Bool, completionHandler: @escaping (Result<[Multiaddr], Error>) -> Void) {
        do {
            let multiaddresses = try addresses.map { try $0.string() }
            var request = "bootstrap/rm?"

            if all {
                request += "all=true&"
            }

            request += buildArgString(multiaddresses)

            fetchPeers(request, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    private func fetchPeers(_ request: String, completionHandler: @escaping (Result<[Multiaddr], Error>) -> Void) {
        parent!.fetchJson(request) { result in
            let transformation = result.flatMap { json -> Result<[Multiaddr], Error> in
                do {
                    guard let peers = json.object?[IpfsCmdString.Peers.rawValue]?.array else {
                        return .success([])
                    }

                    // Make an array of Multiaddr from each peer
                    let addresses: [Multiaddr] = try peers.compactMap {
                        guard let safeString = $0.string else {
                            return nil
                        }

                        return try newMultiaddr(safeString)
                    }

                    return .success(addresses)
                } catch {
                    return .failure(error)
                }
            }
            completionHandler(transformation)
        }
    }
}
