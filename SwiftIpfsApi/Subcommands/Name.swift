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

    @discardableResult
    public func publish(_ hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws -> CancellableRequest {
        return try self.publish(nil, hash: hash, completionHandler: completionHandler)
    }

    @discardableResult
    public func publish(_ id: String? = nil, hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws -> CancellableRequest {
        var request = "name/publish?arg="
        if id != nil { request += id! + "&arg=" }
//        try parent!.fetchJson(request + "/ipfs/" + b58String(hash), completionHandler: completionHandler)
        return try parent!.fetchJson(request + b58String(hash), completionHandler: completionHandler)
    }

    @discardableResult
    public func publish(ipfsPath: String, args: [NamePublishArgType : Any]? = nil, completionHandler: @escaping (JsonType) -> Void) throws -> CancellableRequest {
        // strip the prefix
//        let path = ipfsPath.replacingOccurrences(of: "/ipfs/", with: "")
        let path = ipfsPath.replacingOccurrences(of: "/", with: "%2F")
        var request = "name/publish?arg=\(path)"

        
        let lifetime = args?[.lifetime] ?? "24h"
        let resolve = args?[.resolve] ?? "true"
        
        request += "&lifetime=\(lifetime)&resolve=\(resolve)"
        
        return try parent!.fetchJson(request, completionHandler: completionHandler)
    }

    @discardableResult
    public func resolve(_ hash: Multihash? = nil, completionHandler: @escaping (String) -> Void) throws -> CancellableRequest {
        
        var request = "name/resolve"
        if hash != nil { request += "?arg=" + b58String(hash!) }
        
        return try parent!.fetchJson(request) {
            result in
            
            let resolvedName = result.object?[IpfsCmdString.Path.rawValue]?.string ?? ""
            completionHandler(resolvedName)
        }
//        try parent!.fetchData(request) {
//            (rawJson: NSData) in
//            print(rawJson)
//            
//            guard let json = try NSJSONSerialization.JSONObjectWithData(rawJson, options: NSJSONReadingOptions.AllowFragments) as? [String : AnyObject] else { throw IpfsApiError.JsonSerializationFailed
//            }
//            
//            let resolvedName = json["Path"] as? String ?? ""
//            completionHandler(resolvedName)
//        }
        
    }
}
