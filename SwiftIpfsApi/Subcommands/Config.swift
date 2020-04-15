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
    
    public func show(_ completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("config/show",completionHandler: completionHandler )
    }
    
    public func replace(_ filePath: String, completionHandler: (Bool) -> Void) {
        // FIXME: completion is not being called
        parent!.net.sendTo(parent!.baseUrl+"config/replace?stream-channels=true", filePath: filePath) { _ in
        }
    }
    
    public func get(_ key: String, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("config?arg=" + key) { result in

            completionHandler(.init {
                let json = try result.get()

                guard let value = json.object?[IpfsCmdString.Value.rawValue] else {
                    throw IpfsApiError.swarmError("Config get error: \(String(describing: json.object?[IpfsCmdString.Message.rawValue]?.string))")
                }

                return value
            })
        }
    }
    
    public func set(_ key: String, value: String, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("config?arg=\(key)&arg=\(value)", completionHandler: completionHandler )
    }
}
