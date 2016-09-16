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
    
    public func get(_ hash: Multihash, completionHandler: @escaping ([UInt8]) -> Void) throws {
        try parent!.fetchBytes("block/get?stream-channels=true&arg=\(b58String(hash))", completionHandler: completionHandler)
    }                                                                
    
    public func put(_ data: [UInt8], completionHandler: @escaping (MerkleNode) -> Void) throws {
        let data2 = Data(bytes: UnsafePointer<UInt8>(data), count: data.count)
        
        try parent!.net.sendTo(parent!.baseUrl+"block/put?stream-channels=true", content: data2) {
            result in
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: result, options: JSONSerialization.ReadingOptions.allowFragments) as? [String : AnyObject] else {
                    throw IpfsApiError.jsonSerializationFailed
                }
                
                completionHandler(try merkleNodeFromJson(json as AnyObject))
            } catch {
                print("Block Error:\(error)")
            }
        }
    }
    
    public func stat(_ hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws {
        
        try parent!.fetchJson("block/stat?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
}
