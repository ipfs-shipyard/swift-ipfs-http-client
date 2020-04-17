//
//  Config.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

/** Config controls configuration variables. It works much like 'git config'.
 The configuration values are stored in a config file inside your IPFS repository.
 */
public class Config : ClientSubCommand {
    
    var parent: IpfsApiClient?

    @discardableResult
    public func show(_ completionHandler: @escaping (JsonType) -> Void) throws -> CancellableRequest{
        try parent!.fetchJson("config/show",completionHandler: completionHandler )
    }

    @discardableResult
    public func replace(_ filePath: String, completionHandler: (Bool) -> Void) throws -> CancellableRequest {
        try parent!.net.sendTo(parent!.baseUrl+"config/replace?stream-channels=true", filePath: filePath) {
            _ in
        }
    }

    @discardableResult
    public func get(_ key: String, completionHandler: @escaping (JsonType) throws -> Void) throws -> CancellableRequest {
        try parent!.fetchJson("config?arg=" + key) {
            result in
            guard let value = result.object?[IpfsCmdString.Value.rawValue] else {
                throw IpfsApiError.swarmError("Config get error: \(String(describing: result.object?[IpfsCmdString.Message.rawValue]?.string))")
            }
            
            try completionHandler(value)
            
        }
    }

    @discardableResult
    public func set(_ key: String, value: String, completionHandler: @escaping (JsonType) throws -> Void) throws -> CancellableRequest {
        try parent!.fetchJson("config?arg=\(key)&arg=\(value)", completionHandler: completionHandler )
    }
}
