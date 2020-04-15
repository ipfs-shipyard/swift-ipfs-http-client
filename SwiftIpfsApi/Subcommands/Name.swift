//
//  Name.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash

/** IPNS is a PKI namespace, where names are the hashes of public keys, and
 the private key enables publishing new (signed) values. In both publish
 and resolve, the default value of <name> is your own identity public key.
 */
public class Name : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public enum NamePublishArgType {
        case path
        case resolve
        case lifetime
        case ttl
        case key
    }
    
    public func publish(_ hash: Multihash, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        publish(nil, hash: hash, completionHandler: completionHandler)
    }
    
    public func publish(_ id: String? = nil, hash: Multihash, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        var request = "name/publish?arg="
        if let safeIdentifier = id {
            request += safeIdentifier + "&arg="
        }

        parent!.fetchJson(request + b58String(hash), completionHandler: completionHandler)
    }
    
    public func publish(ipfsPath: String, args: [NamePublishArgType : Any]? = nil, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        // strip the prefix
//        let path = ipfsPath.replacingOccurrences(of: "/ipfs/", with: "")
        let path = ipfsPath.replacingOccurrences(of: "/", with: "%2F")
        var request = "name/publish?arg=\(path)"

        let lifetime = args?[.lifetime] ?? "24h"
        let resolve = args?[.resolve] ?? "true"
        
        request += "&lifetime=\(lifetime)&resolve=\(resolve)"
        
        parent!.fetchJson(request, completionHandler: completionHandler)
    }

    public func resolve(_ hash: Multihash? = nil, completionHandler: @escaping (Result<String, Error>) -> Void) {
        var request = "name/resolve"

        if let safeHash = hash {
            request += "?arg=" + b58String(safeHash)
        }
        
        parent!.fetchJson(request) { result in
            switch result {
            case .success(let json):
                completionHandler(.success(json.object?[IpfsCmdString.Path.rawValue]?.string ?? ""))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}
