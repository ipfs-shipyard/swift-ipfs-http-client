//
//  MerkleNode.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 20/10/15.
//
//  Licensed under MIT See LICENCE file in the root of this project for details.

import Foundation
import SwiftMultihash

public enum MerkleNodeError : Error {
    case jsonFormatError
    case requiredValueMissing(String)
}

struct MerkleData {
    var hash: String?
    var name: String?
    var size: Int?
    var type: Int?
    var links: [MerkleNode]?
    var data: [UInt8]?
}

public struct MerkleNode: Equatable {
    public let hash: Multihash?
    public let name: String?
    public let size: Int?
    public let type: Int?
    public let links: [MerkleNode]?
    public let data: [UInt8]?
    
    public init(hash: String) throws {
        try self.init(hash: hash, name: nil)
    }
    
    public init(hash: String, name: String?) throws {
        try self.init(hash: hash, name: name, size: nil, type: nil, links: nil, data: nil)
    }
    
    init(data: MerkleData) throws {
        guard let safeHash = data.hash else {
            throw MerkleNodeError.requiredValueMissing("No hash provided!")
        }
        try self.init(hash: safeHash, name: data.name, size: data.size, type: data.type, links: data.links, data: data.data)
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


public func merkleNodesFromJson(_ rawJson: JsonType) throws -> [MerkleNode?] {
    var nodes = [MerkleNode?]()
    
    switch rawJson {
    case .object(_):
        return [try merkleNodeFromJson2(rawJson)]
//        return try merkleNodesFromJson(JsonType.Array([rawJson]))
        
    case .array(let arr):
        for obj in arr {
            nodes.append(try merkleNodeFromJson2(obj))
        }
    default:
        break
    }
    return nodes
}
/** This method will find all the objects in the rawJson that refer to the same
    name and build merkle nodes from them. It will return the new merkle nodes.
 */
// FIXME: Assumption that hash is always last is incorrect.
public func _merkleNodesFromJson(_ rawJson: JsonType) throws -> [MerkleNode?] {
    
    var nodes = [MerkleNode?]()
    
    switch rawJson {
    case .object(_):
        return try merkleNodesFromJson(JsonType.array([rawJson]))
        
    case .array(let arr):
        
        /// we need a place to hold the objects with the same name
        _ = [String : MerkleData]()
        var curMerkle = MerkleData()
        
        for obj in arr {
            /// Go through all values for the object and add them to the merkledata
            for (key, value) in obj.object! {
                switch key {
                case "Name":
                    guard let name = value.string else { continue }
                    curMerkle.name = name
                    
                case "Bytes", "Size":
                    guard let bytes = value.number?.intValue else { continue }

                    /// Add to previous size if it exists.
                    curMerkle.size = (curMerkle.size ?? 0) + bytes

                case "Hash":
                    curMerkle.hash = value.string
                    /** The hash marks the end of the objects of a given name, so 
                        we create a MerkleNode and add it to our return array. 
                     */

                    nodes.append(try MerkleNode(data: curMerkle))
                    /// time to make a new merkledata
                    curMerkle = MerkleData()
                    
                case "Type":
                      curMerkle.type = value.number?.intValue
                case "Links":
                    
                    if let rawLinks = value.array {
                        let tmplinks = try merkleNodesFromJson(JsonType.array(rawLinks))
                        curMerkle.links = tmplinks.compactMap{ $0 }
                    }

                case "Data":
                    if let strDat = value.string {
                        curMerkle.data = [UInt8](strDat.utf8)
                    }
                   
                case "Objects":
                    guard let objects = value.array else {
                        throw IpfsApiError.swarmError("ls error: No Objects in JSON data.")
                    }

                    return try merkleNodesFromJson(JsonType.array(objects))
                    
                default:
                    print("\(key) Not yet handled")
                }
            }
        }
        break
    default:
        break
    }
    
    return nodes
}

public func merkleNodeFromJson2(_ rawJson: JsonType) throws -> MerkleNode {
    guard case .object(let objs) = rawJson else {
        throw MerkleNodeError.jsonFormatError
    }
    
    guard let hash: String = objs["Hash"]?.string ?? objs["Key"]?.string else {
        throw MerkleNodeError.requiredValueMissing("Neither Hash nor Key exist")
    }

    let name     = objs["Name"]?.string
    let size     = objs["Size"]?.number as? Int
    let type     = objs["Type"]?.number as? Int

    var links: [MerkleNode]?
    if let rawLinks = objs["Links"]?.array {
        links    = try rawLinks.map { try merkleNodeFromJson2($0) }
    }
    
    /// Should this be UInt8? The command line output looks like UInt16
    var data: [UInt8]?
    if let strDat = objs["Data"]?.string {
        data = [UInt8](strDat.utf8)
    }

    return try MerkleNode(hash: hash, name: name, size: size, type: type, links: links, data: data)
}

public func merkleNodeFromJson(_ rawJson: AnyObject) throws -> MerkleNode {
    // turn it into a dictionary
    let objs     = rawJson as! [String : AnyObject]
    
    let hash     = objs["Hash"] == nil ? objs["Key"] as! String : objs["Hash"] as! String
    let name     = objs["Name"] as? String
    let size     = objs["Size"] as? Int
    let type     = objs["Type"] as? Int
    
    var links: [MerkleNode]?
    if let rawLinks = objs["Links"] as? [AnyObject] {
        links    = try rawLinks.map { try merkleNodeFromJson($0) }
    }

    // Should this be UInt8? The command line output looks like UInt16
    var data: [UInt8]?
    if let strDat = objs["Data"] as? String {
        data = [UInt8](strDat.utf8)
    }

    return try MerkleNode(hash: hash, name: name, size: size, type: type, links: links, data: data)
}
