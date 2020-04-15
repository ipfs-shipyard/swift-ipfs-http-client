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
        case unixFsDir = "unixfs-dir"
    }
    
    public enum ObjectPatchCommand: String {
        case addLink = "add-link"
        case rmLink = "rm-link"
        case setData = "set-data"
        case appendData = "append-data"
    }
    
    /**
     IpfsObject new is a plumbing command for creating new DAG nodes.
     By default it creates and returns a new empty merkledag node, but
     you may pass an optional template argument to create a preformatted
     node.
     
     Available templates:
    	* unixfs-dir
     */
    public func new(_ template: ObjectTemplates? = nil, completionHandler: @escaping (Result<MerkleNode, Error>) -> Void) {
        var request = "object/new?stream-channels=true"

        if let safeTemplate = template {
            request += "&arg=\(safeTemplate.rawValue)"
        }

         parent!.fetchJson(request) { result in
            let transformation = result.flatMap { json -> Result<MerkleNode, Error> in
                return .init(catching: { try merkleNodeFromJson2(json) } )
            }
            completionHandler(transformation)
        }
    }
    
    /** IpfsObject put is a plumbing command for storing DAG nodes.
     Its input is a byte array, and the output is a base58 encoded multihash.
     */
    public func put(_ data: [UInt8], completionHandler: @escaping (Result<MerkleNode, Error>) -> Void) {
        let data = Data(bytes: UnsafePointer<UInt8>(data), count: data.count)
        
        parent!.net.sendTo(parent!.baseUrl+"object/put?stream-channels=true", content: data) { result in
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
    
    /** IpfsObject get is a plumbing command for retreiving DAG nodes.
     Its input is a base58 encoded Multihash and it returns a MerkleNode.
     */
    public func get(_ hash: Multihash, completionHandler: @escaping (Result<MerkleNode, Error>) -> Void) {
        parent!.fetchJson("object/get?stream-channels=true&arg=" + b58String(hash)) { result in
            let transformation = result.flatMap { json -> Result<MerkleNode, Error> in
                do {
                    guard var res = json.object else {
                        return .failure(IpfsApiError.resultMissingData("No object found!"))
                    }

                    res["Hash"] = .string(b58String(hash))
                    return .success(try merkleNodeFromJson2(.object(res)))
                } catch {
                    return .failure(error)
                }
            }
            completionHandler(transformation)
        }
    }
    
    public func links(_ hash: Multihash, completionHandler: @escaping (Result<MerkleNode, Error>) -> Void) {
        parent!.fetchJson("object/links?stream-channels=true&arg=" + b58String(hash)) { result in
            completionHandler(.init(catching: {
                try merkleNodeFromJson2(try result.get())
            }))
        }
    }
    
    public func stat(_ hash: Multihash, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("object/stat?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func data(_ hash: Multihash, completionHandler: @escaping (Result<[UInt8], Error>) -> Void) {
        parent!.fetchBytes("object/data?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
    }

    // change root to String ?
    public func patch(_ root: Multihash, cmd: ObjectPatchCommand, args: String..., completionHandler: @escaping (Result<MerkleNode, Error>) -> Void) {
        var request = "object/patch"

        switch cmd {
        case .addLink:
            print("patch add link")

            guard args.count == 2 else {
                return completionHandler(.failure(IpfsApiError.ipfsObjectError("Wrong number of arguments to \(cmd.rawValue)")))
            }
            request += "/add-link"
        case .rmLink:
            print("patch remove link")
            request += "/rm-link"
        case .setData:
            print("patch set data")
            request += "/set-data"
        case .appendData:
            print("patch append data")
            request += "/append-data"
        }
        
        request += "?arg=\(b58String(root))&"
        
        request += buildArgString(args)
        
        parent!.fetchJson(request) { result in
            completionHandler(.init {
                try merkleNodeFromJson2(try result.get())
            })
        }
    }
}
