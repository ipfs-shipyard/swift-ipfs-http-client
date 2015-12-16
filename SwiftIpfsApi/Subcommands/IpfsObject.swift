//
//  IpfsObject.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation
import SwiftMultihash

public class IpfsObject : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public enum ObjectTemplates: String {
        case UnixFsDir = "unixfs-dir"
    }
    
    public enum ObjectPatchCommand: String {
        case AddLink    = "add-link"
        case RmLink     = "rm-link"
        case SetData    = "set-data"
        case AppendData = "append-data"
    }
    
    /**
     IpfsObject new is a plumbing command for creating new DAG nodes.
     By default it creates and returns a new empty merkledag node, but
     you may pass an optional template argument to create a preformatted
     node.
     
     Available templates:
    	* unixfs-dir
     */
    public func new(template: ObjectTemplates? = nil, completionHandler: (MerkleNode) throws -> Void) throws {
        var request = "object/new?stream-channels=true"
        if template != nil { request += "&arg=\(template!.rawValue)" }
        try parent!.fetchJson(request) {
            result in
            try completionHandler( try merkleNodeFromJson2(result) )
        }
    }
    
    /** IpfsObject put is a plumbing command for storing DAG nodes.
     Its input is a byte array, and the output is a base58 encoded multihash.
     */
    public func put(data: [UInt8], completionHandler: (MerkleNode) -> Void) throws {
        let data2 = NSData(bytes: data, length: data.count)
        
        try parent!.net.sendTo(parent!.baseUrl+"object/put?stream-channels=true", content: data2) {
            result in
            
            do {
                print(result)
                guard let json = try NSJSONSerialization.JSONObjectWithData(result, options: NSJSONReadingOptions.AllowFragments) as? [String : AnyObject] else {
                    throw IpfsApiError.JsonSerializationFailed
                }
                
                completionHandler(try merkleNodeFromJson(json))
            } catch {
                print("IpfsObject Error:\(error)")
            }
        }
    }
    
    /** IpfsObject get is a plumbing command for retreiving DAG nodes.
     Its input is a base58 encoded Multihash and it returns a MerkleNode.
     */
    public func get(hash: Multihash, completionHandler: (MerkleNode) -> Void) throws {
        
        try parent!.fetchJson("object/get?stream-channels=true&arg=" + b58String(hash)){
            result in
            
            guard var res = result.object else { throw IpfsApiError.ResultMissingData("No object found!")}
            res["Hash"] = .String(b58String(hash))
            completionHandler(try merkleNodeFromJson2(.Object(res)))
        }
    }
    
    public func links(hash: Multihash, completionHandler: (MerkleNode) throws -> Void) throws {
        
        try parent!.fetchJson("object/links?stream-channels=true&arg=" + b58String(hash)){
            result in
            try completionHandler(try merkleNodeFromJson2(result))
        }
    }
    
    public func stat(hash: Multihash, completionHandler: (JsonType) -> Void) throws {
        
        try parent!.fetchJson("object/stat?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func data(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        
        try parent!.fetchBytes("object/data?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func patch(root: Multihash, cmd: ObjectPatchCommand, args: String..., completionHandler: (MerkleNode) throws -> Void) throws {
        
        var request: String = "object/patch?arg=\(b58String(root))&arg=\(cmd.rawValue)&"
        
        if cmd == .AddLink && args.count != 2 {
            throw IpfsApiError.IpfsObjectError("Wrong number of arguments to \(cmd.rawValue)")
        }
        
        request += buildArgString(args)
        
        try parent!.fetchJson(request) {
            result in
            try completionHandler(try merkleNodeFromJson2(result))
        }
    }
}