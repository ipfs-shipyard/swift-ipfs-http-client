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
    
//    init(hash: String? = nil, name: String? = nil, size: Int? = nil, type: Int? = nil, links: [MerkleNode]? = nil, data: [UInt8]? = nil) {
//        self.name = name
//    }
}

/// TODO: Change this to a struct?
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
    
    convenience init(data: MerkleData) throws {
        guard data.hash != nil else {
            throw MerkleNodeError.requiredValueMissing("No hash provided!")
        }
        try self.init(hash: data.hash!, name: data.name, size: data.size, type: data.type, links: data.links, data: data.data)
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
    case .Object(_):
        return [try merkleNodeFromJson2(rawJson)]
//        return try merkleNodesFromJson(JsonType.Array([rawJson]))
        
    case .Array(let arr):
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
/// FIXME: Assumption that hash is always last is incorrect.
public func _merkleNodesFromJson(_ rawJson: JsonType) throws -> [MerkleNode?] {
    
    var nodes = [MerkleNode?]()
    
    switch rawJson {
    case .Object(_):
        //return [try merkleNodeFromJson2(rawJson)]
        return try merkleNodesFromJson(JsonType.Array([rawJson]))
        
    case .Array(let arr):
        
        /// we need a place to hold the objects with the same name
        _ = [String : MerkleData]()
//        var curMerkle: MerkleData?
        var curMerkle = MerkleData()
        
        for obj in arr {
//            print("arr obj is \(obj)")
//            let name = obj.object?["Name"]!
//            print("name is \(name)")
            
            /// Go through all values for the object and add them to the merkledata
            for (key, value) in obj.object! {
                switch key {
                case "Name":
                    
                    guard let name = value.string else { continue }
                    curMerkle.name = name
//                    curMerkle = merkles[name]
//                    if curMerkle == nil {
//                        curMerkle = MerkleData()//name: name)
//                        curMerkle?.name = name
//                        merkles[name] = curMerkle
//                        
//                    }
                    
                case "Bytes", "Size":
//                    guard curMerkle != nil else { print("Bytes, no current merkle!") ; continue }
                    guard let bytes = value.number?.intValue else { continue }

                    /// Add to previous size if it exists.
//                    curMerkle!.size = (curMerkle!.size ?? 0) + bytes
                    curMerkle.size = (curMerkle.size ?? 0) + bytes
                    
//                    merkles[curMerkle!.name!] = curMerkle
                    
                case "Hash":
//                    guard curMerkle != nil else { print("Hash, no current merkle!") ; continue }
//                    curMerkle?.hash = value.string
                    curMerkle.hash = value.string
                    /** The hash marks the end of the objects of a given name, so 
                        we create a MerkleNode and add it to our return array. 
                     */
//                    nodes.append(try MerkleNode(data: curMerkle!))
                    nodes.append(try MerkleNode(data: curMerkle))
                    /// time to make a new merkledata
                    curMerkle = MerkleData()
                    
                case "Type":
//                    guard curMerkle != nil else { print("Type, no current merkle!") ; continue }
//                    curMerkle?.type = value.number?.intValue
                      curMerkle.type = value.number?.intValue
                case "Links":
//                    guard curMerkle != nil else { print("Links, no current merkle!") ; continue }
                    
                    if let rawLinks = value.array {
//                        curMerkle?.links = try rawLinks.map { try merkleNodeFromJson2($0) }
//                        curMerkle.links = try rawLinks.map { try merkleNodeFromJson2($0) }
                        

                        let tmplinks = try merkleNodesFromJson(JsonType.Array(rawLinks))
                        /// Unwrap optionals
                        let links = tmplinks.compactMap{ $0 }
                        
                        curMerkle.links = links
                    }

                case "Data":
//                    guard curMerkle != nil else { print("Data, no current merkle!") ; continue }
                    if let strDat = value.string {
//                        curMerkle!.data = [UInt8](strDat.utf8)
                        curMerkle.data = [UInt8](strDat.utf8)
                    }
                   
                case "Objects":
                    guard let objects = value.array else {
                        throw IpfsApiError.swarmError("ls error: No Objects in JSON data.")
                    }

                    return try merkleNodesFromJson(JsonType.Array(objects))
                    
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
    guard case .Object(let objs) = rawJson else {
        throw MerkleNodeError.jsonFormatError
    }
    
    guard let hash: String = objs["Hash"]?.string ?? objs["Key"]?.string else {
        throw MerkleNodeError.requiredValueMissing("Neither Hash nor Key exist")
    }
//    var hash: String
//    if let jsonHash = objs["Hash"]?.string { hash = jsonHash }
//    else if let jsonKey = objs["Key"]?.string { hash = jsonKey }
//    else { throw MerkleNodeError.RequiredValueMissing("Neither Hash nor Key exist") }

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
    /// turn it into a dictionary
    let objs     = rawJson as! [String : AnyObject]
    
    let hash     = objs["Hash"] == nil ? objs["Key"] as! String : objs["Hash"] as! String
    let name     = objs["Name"] as? String
    let size     = objs["Size"] as? Int
    let type     = objs["Type"] as? Int
    
    var links: [MerkleNode]?
    if let rawLinks = objs["Links"] as? [AnyObject] {
        links    = try rawLinks.map { try merkleNodeFromJson($0) }
    }

    /// Should this be UInt8? The command line output looks like UInt16
    var data: [UInt8]?
    if let strDat = objs["Data"] as? String {
        data = [UInt8](strDat.utf8)
    }

    return try MerkleNode(hash: hash, name: name, size: size, type: type, links: links, data: data)
}

public func == (lhs: MerkleNode, rhs: MerkleNode) -> Bool {
    return lhs.hash == rhs.hash
}
