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
    public func new(_ template: ObjectTemplates? = nil, completionHandler: @escaping (MerkleNode) throws -> Void) throws {
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
    public func put(_ data: [UInt8], completionHandler: @escaping (MerkleNode) -> Void) throws {
        let data2 = Data(bytes: UnsafePointer<UInt8>(data), count: data.count)
        
        try parent!.net.sendTo(parent!.baseUrl+"object/put?stream-channels=true", content: data2) {
            result in
            
            do {
                print(result)
                guard let json = try JSONSerialization.jsonObject(with: result, options: JSONSerialization.ReadingOptions.allowFragments) as? [String : AnyObject] else {
                    throw IpfsApiError.jsonSerializationFailed
                }
                
                completionHandler(try merkleNodeFromJson(json as AnyObject))
            } catch {
                print("IpfsObject Error:\(error)")
            }
        }
    }
    
    /** IpfsObject get is a plumbing command for retreiving DAG nodes.
     Its input is a base58 encoded Multihash and it returns a MerkleNode.
     */
    public func get(_ hash: Multihash, completionHandler: @escaping (MerkleNode) -> Void) throws {
        
        try parent!.fetchJson("object/get?stream-channels=true&arg=" + b58String(hash)){
            result in
            
            guard var res = result.object else { throw IpfsApiError.resultMissingData("No object found!")}
            res["Hash"] = .String(b58String(hash))
            completionHandler(try merkleNodeFromJson2(.Object(res)))
        }
    }
    
    public func links(_ hash: Multihash, completionHandler: @escaping (MerkleNode) throws -> Void) throws {
        
        try parent!.fetchJson("object/links?stream-channels=true&arg=" + b58String(hash)){
            result in
            try completionHandler(try merkleNodeFromJson2(result))
        }
    }
    
    public func stat(_ hash: Multihash, completionHandler: @escaping (JsonType) -> Void) throws {
        
        try parent!.fetchJson("object/stat?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func data(_ hash: Multihash, completionHandler: @escaping ([UInt8]) -> Void) throws {
        
        try parent!.fetchBytes("object/data?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
//    public func patch(_ root: Multihash, cmd: ObjectPatchCommand, args: String..., completionHandler: @escaping (MerkleNode) throws -> Void) throws {
//
//        var request: String = "object/patch?arg=\(b58String(root))&arg=\(cmd.rawValue)&"
//
//        if cmd == .AddLink && args.count != 2 {
//            throw IpfsApiError.ipfsObjectError("Wrong number of arguments to \(cmd.rawValue)")
//        }
//
//        request += buildArgString(args)
//
//        try parent!.fetchJson(request) {
//            result in
//            try completionHandler(try merkleNodeFromJson2(result))
//        }
//    }
    // change root to String ?
    public func patch(_ root: Multihash, cmd: ObjectPatchCommand, args: String..., completionHandler: @escaping (MerkleNode) throws -> Void) throws {
        
        var request: String = "object/patch"
        switch cmd {
        case .AddLink:
            print("patch add link")
            guard args.count == 2 else {
                throw IpfsApiError.ipfsObjectError("Wrong number of arguments to \(cmd.rawValue)")
            }
            request += "/add-link"
        case .RmLink:
            print("patch remove link")
            request += "/rm-link"
        case .SetData:
            print("patch set data")
            request += "/set-data"
        case .AppendData:
            print("patch append data")
            request += "/append-data"
        }
        
        request += "?arg=\(b58String(root))&"
        
        request += buildArgString(args)
        
        try parent!.fetchJson(request) {
            result in
            try completionHandler(try merkleNodeFromJson2(result))
        }
    }
}
