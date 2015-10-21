//
//  IPFSApi.swift
//  SwiftIPFSApi
//
//  Created by Teo on 20/10/15.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation
import SwiftMultiaddr
import SwiftMultihash

public enum PinType {
    case all
    case direct
    case indirect
    case recursive
}

enum IPFSAPIError : ErrorType {
    case InvalidURL
    case NilData
    case DataTaskError(NSError)
}

public class IPFSApi {

    public static var baseURL: String = ""
    
    public let host: String
    public let port: Int
    public let version: String
    
    /// Second Tier commands
    public let pin: Pin
    public let swarm: Swarm
/**
    public convenience init(addr: Multiaddr) throws {
        /// Get the host and port number from the Multiaddr
        let addString = addr.string()
        self.init(addr.)
    }

    public convenience init(addr: String) throws {
        try self.init(addr: newMultiaddr(addr))
    }
*/
    public init(host: String, port: Int, version: String = "/api/v0/") throws {
        self.host = host
        self.port = port
        self.version = version
        
        IPFSApi.baseURL = "http://\(host):\(port)/\(version)"
        
        pin = Pin()
        swarm = Swarm()
    }
    
    
    /// Tier 1 commands
    
    public func add(file :NSURL) throws -> MerkleNode {
        return try MerkleNode(hash: "")
    }
    
    public func add(files: [NSURL]) throws -> [MerkleNode] {
        return []
    }
    
    public func ls(hash: Multihash) throws -> [MerkleNode] {
        return []
    }
    
    public func cat(hash: Multihash)  throws {
        
    }
    
    public func get(hash: Multihash) throws -> [UInt8] {
        return []
    }
    
    public func refs(hash: Multihash, recursive: Bool) throws -> [String : String] {
        return [:]
    }
    
    public func resolve(scheme: String, hash: Multihash, recursive: Bool) throws -> [String : String] {
        return [:]
    }
    
    public func dns(domain: String) throws -> String {
        return ""
    }
    
    public func mount(ipfsRoot: NSFileHandle, ipnsRoot: NSFileHandle) throws -> [String : String] {
        return [:]
    }
}


/// Move these to own file
extension IPFSApi {
    public struct Pin {
        public func add() {
            
        }
        
        public func ls() {
            
        }

        public func rm() {
            
        }

    }
}

public func fetchData(path: String, completionHandler: (NSData) -> Void) throws {
    let fullURL = IPFSApi.baseURL + path
    guard let url = NSURL(string: fullURL) else { throw IPFSAPIError.InvalidURL }
    
    let task = NSURLSession.sharedSession().dataTaskWithURL(url) {
        (data: NSData?, response: NSURLResponse?, error: NSError?) in
        do {
            if error != nil { throw IPFSAPIError.DataTaskError(error!) }
            guard let data = data else { throw IPFSAPIError.NilData }
            
            completionHandler(data)
            
        } catch {
            print("Error ", error, "in completionHandler passed to fetchData ")
        }
    }
    
    task.resume()
}

public struct Repo {
    
}

public struct IPFSObject {
    
}

public struct Swarm {
    
    public func peers(completionHandler: ([Multiaddr]) -> Void) throws {
        try fetchData("swarm/peers?stream-channels=true") {
            (data: NSData) in
            do {
                print("The peers:",NSString(data: data, encoding: NSUTF8StringEncoding))
                // Parse the data into an array of string : anyobject dictionaries.
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : [String]] else { return }
                let tmp = json["Strings"]! as [String]
                
                var addresses: [Multiaddr] = []
                for entry in tmp {
                    addresses.append(try newMultiaddr(entry))
                }
                /// convert the data into a Multiaddr array and pass it to the handler
                completionHandler(addresses)
            } catch {
                print("Swarm peers error serializing JSON")
            }
        }
    }
}

public struct Bootstrap {
    
}

public struct Block {
    
}

public struct Diag {
    
}

public struct Config {
    
}

public struct Refs {
    
}

public struct Update {
    
}

public struct DHT {
    
}

public struct File {
    
}

public struct Stats {
    
}

public struct Name {
    
}