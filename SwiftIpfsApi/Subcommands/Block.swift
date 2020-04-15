//
//  Block.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash
import Foundation

public class Block : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func get(_ hash: Multihash, completionHandler: @escaping (Result<[UInt8], Error>) -> Void) {
        parent!.fetchBytes("block/get?stream-channels=true&arg=\(b58String(hash))", completionHandler: completionHandler)
    }                                                                
    
    public func put(_ data: [UInt8], completionHandler: @escaping (Result<MerkleNode, Error>) -> Void) {
        let data = Data(bytes: UnsafePointer<UInt8>(data), count: data.count)
        
        parent!.net.sendTo(parent!.baseUrl+"block/put?stream-channels=true", content: data) { result in
            let transformation: Result<MerkleNode, Error> = .init {
                guard let json = try JSONSerialization.jsonObject(with: data,
                                                                  options: .allowFragments) as? [String : AnyObject] else {
                    throw IpfsApiError.jsonSerializationFailed
                }

                return try merkleNodeFromJson(json as AnyObject)
            }
            completionHandler(transformation)
        }
    }
    
    public func stat(_ hash: Multihash, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("block/stat?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
}
