//
//  MerkleNode.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 20/10/15.
//
//  Licensed under MIT See LICENCE file in the root of this project for details.

import Foundation
import SwiftMultihash

public class MerkleNode {
    public let hash: Multihash?
    public let name: String?
    public let size: Int?
    public let type: Int?
    public let links: [MerkleNode]?
    public let data: [UInt8]?
    
    public convenience init(hash: String) throws {
        try self.init(hash: hash, name: nil)
    }
    
    public convenience init(hash: String, name: String?) throws {
        try self.init(hash: hash, name: name, size: nil, type: nil, links: nil, data: nil)
    }
    
    public init(hash: String, name: String?, size: Int?, type: Int?, links: [MerkleNode]?, data: [UInt8]?) throws {
        self.name = name
        self.size = size
        self.type = type
        self.links = links
        self.data = data
        
        /// hash must be set before exiting with a throw.
        do {
            self.hash = try SwiftMultihash.fromB58String(hash)
        } catch {
            self.hash = nil
            throw error
        }
    }
}

public func merkleNodeFromJSON(rawJSON: AnyObject) throws -> MerkleNode {
    /// turn it into a dictionary
    let objs     = rawJSON as! [String : AnyObject]
    
    let hash     = objs["Hash"] == nil ? objs["Key"] as! String : objs["Hash"] as! String
    let name     = objs["Name"] as? String
    let size     = objs["Size"] as? Int
    let type     = objs["Type"] as? Int
    
    var links: [MerkleNode]?
    if let rawLinks = objs["Links"] as? [AnyObject] {
        links    = try rawLinks.map {
            (rawJSON) -> MerkleNode in
            return try merkleNodeFromJSON(rawJSON)
            }
    }

    let data     = objs["Data"] as? [UInt8]

    return try MerkleNode(hash: hash, name: name, size: size, type: type, links: links, data: data)
}

public func == (lhs: MerkleNode, rhs: MerkleNode) -> Bool {
    return lhs.hash == rhs.hash
}
