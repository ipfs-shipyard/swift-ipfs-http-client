//
//  Block.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash

public class Block : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func get(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        let hashString = b58String(hash)
        try parent!.fetchBytes("block/get?stream-channels=true&arg=" + hashString, completionHandler: completionHandler)
    }
    
    public func put(data: [UInt8], completionHandler: (MerkleNode) -> Void) throws {
        let data2 = NSData(bytes: data, length: data.count)
        
        try parent!.net.sendTo(parent!.baseUrl+"block/put?stream-channels=true", content: data2) {
            result in
            
            do {
                print(result)
                guard let json = try NSJSONSerialization.JSONObjectWithData(result, options: NSJSONReadingOptions.AllowFragments) as? [String : AnyObject] else {
                    throw IpfsApiError.JsonSerializationFailed
                }
                
                completionHandler(try merkleNodeFromJson(json))
            } catch {
                print("Block Error:\(error)")
            }
        }
    }
    
    public func stat(hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("block/stat?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
}