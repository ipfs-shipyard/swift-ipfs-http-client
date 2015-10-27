//
//  IpfsApi.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 20/10/15.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation
import SwiftMultiaddr
import SwiftMultihash

public protocol IpfsApiClient {
    var baseUrl: String { get }
}

protocol ClientSubCommand {
    var parent: IpfsApiClient? { get set }
}

extension IpfsApiClient {
    
    func fetchDictionary(path: String, completionHandler: ([String : AnyObject]) throws -> Void) throws {
        try fetchData(path) {
            (data: NSData) in
            
            /// Check for streamed JSON format and wrap & separate.
            guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : AnyObject] else { throw IpfsApiError.JsonSerializationFailed
            }
            
            try completionHandler(json)
        }
    }
    
    func fetchData(path: String, completionHandler: (NSData) throws -> Void) throws {
        
        let fullUrl = baseUrl + path
        guard let url = NSURL(string: fullUrl) else { throw IpfsApiError.InvalidUrl }
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url) {
            (data: NSData?, response: NSURLResponse?, error: NSError?) in
            
            do {
                guard error == nil else { throw IpfsApiError.DataTaskError(error!) }
                guard let data = data else { throw IpfsApiError.NilData }
                
                //print("The data:",NSString(data: data, encoding: NSUTF8StringEncoding))
                
                try completionHandler(data)
            
            } catch {
                print("Error ", error, "in completionHandler passed to fetchData ")
            }
        }
        
        task.resume()
    }
}

public enum PinType {
    case all
    case direct
    case indirect
    case recursive
}

enum IpfsApiError : ErrorType {
    case InitError
    case InvalidUrl
    case NilData
    case DataTaskError(NSError)
    case JsonSerializationFailed
    case SwarmError(String)
}

public class IpfsApi : IpfsApiClient {

    public var baseUrl: String = ""
    
    public let host: String
    public let port: Int
    public let version: String
    
    /// Second Tier commands
    public let repo = Repo()
    public let pin = Pin()
    public let swarm = Swarm()


    public convenience init(addr: Multiaddr) throws {
        /// Get the host and port number from the Multiaddr
        let addressString = try addr.string()
        var protoComponents = addressString.characters.split{$0 == "/"}.map(String.init)
        if  protoComponents[0].hasPrefix("ip") == true &&
            protoComponents[2].hasPrefix("tcp") == true {
                
            try self.init(host: protoComponents[1],port: Int(protoComponents[3])!)
        } else {
            throw IpfsApiError.InitError
        }
    }

    public convenience init(addr: String) throws {
        try self.init(addr: newMultiaddr(addr))
    }

    public init(host: String, port: Int, version: String = "/api/v0/") throws {
        self.host = host
        self.port = port
        self.version = version
        
        baseUrl = "http://\(host):\(port)\(version)"
        
        /** All of IPFSApi's properties need to be set before we can use self which
            is why we can't just init the sub commands with self */
        repo.parent = self
        pin.parent = self
        swarm.parent = self
        
    }
    
    
    /// Tier 1 commands
    
    public func add(filePath: String, completionHandler: ([MerkleNode]) -> Void) throws {
        try self.add([filePath], completionHandler: completionHandler)
    }
    
    public func add(filePaths: [String], completionHandler: ([MerkleNode]) -> Void) throws {

        try HttpIo.sendTo(baseUrl+"add?stream-channels=true", content: filePaths) {
            result in

            let newRes = fixStreamJson(result)
           
            /// We have to catch the thrown errors inside the completion closure 
            /// from within it.
            do {
                guard let json = try NSJSONSerialization.JSONObjectWithData(newRes, options: NSJSONReadingOptions.AllowFragments) as? [[String : String]] else {
                    throw IpfsApiError.JsonSerializationFailed
                }

                /// Turn each component into a MerkleNode
                let merkles = try json.map {
                    rawJSON in
                    return try merkleNodeFromJSON(rawJSON)
                }
                
                completionHandler(merkles)
                
            } catch {
                print("Error inside add completion handler: \(error)")
            }
        }
    }

    public func ls(hash: Multihash, completionHandler: ([MerkleNode]) -> Void) throws {
        
        let hashString = b58String(hash)
        try fetchDictionary("ls/"+hashString) {
            (jsonDictionary: Dictionary) in
            
            do {
                guard let objects = jsonDictionary["Objects"] as? [AnyObject] else {
                    throw IpfsApiError.SwarmError("ls error: No Objects in JSON data.")
                }
                
                let merkles = try objects.map {
                     try merkleNodeFromJSON($0)
                }
                
                completionHandler(merkles)
            } catch {
                print("ls Error")
            }
        }
    }
    

    public func cat(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        let hashString = b58String(hash)
        try fetchData("cat/"+hashString) {
            (data: NSData) in
            
            /// Convert the data to a byte array
            let count = data.length / sizeof(UInt8)
            // create an array of Uint8
            var bytes = [UInt8](count: count, repeatedValue: 0)

            // copy bytes into array
            data.getBytes(&bytes, length:count * sizeof(UInt8))
            
            completionHandler(bytes)
        }
        return
    }
    
    public func get(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        try self.cat(hash, completionHandler: completionHandler)
    }
    
    public func refs(hash: Multihash, recursive: Bool, completionHandler: ([Multihash]) -> Void) throws {
        
        let hashString = b58String(hash)
        try fetchData("refs?arg=" + hashString + "&r=\(recursive)") {
            (data: NSData) in
            do {
                
                let fixedData = fixStreamJson(data)
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(fixedData, options: NSJSONReadingOptions.MutableContainers) as? [[String : AnyObject]] else { throw IpfsApiError.JsonSerializationFailed
                }
                
                /// Extract the references and add them to an array.
                var refs: [Multihash] = []
                for obj in json {
                    if let ref = obj["Ref"]{
                        let mh = try fromB58String(ref as! String)
                        refs.append(mh)
                    }
                }
                
                completionHandler(refs)
                
            } catch {
                print("Error \(error)")
            }
        }
    }
    
    public func resolve(scheme: String, hash: Multihash, recursive: Bool, completionHandler: ([String : AnyObject]) -> Void) throws {
        let hashString = b58String(hash)
        try fetchDictionary("resolve?arg=/\(scheme)/\(hashString)&r=\(recursive)") {
            (jsonDictionary: Dictionary) in
            
            completionHandler(jsonDictionary)
        }
    }
    
    public func dns(domain: String, completionHandler: (String) -> Void) throws {
        try fetchDictionary("dns?arg=" + domain) {
            (jsonDict: Dictionary) in
            
                guard let path = jsonDict["Path"] as? String else { throw IpfsApiError.NilData }
                completionHandler(path)
        }
    }
    
    public func mount(ipfsRoot: NSFileHandle, ipnsRoot: NSFileHandle) throws -> [String : String] {
        return [:]
    }
}


/// Move these to own file

public class Pin : ClientSubCommand {
    
    var parent: IpfsApiClient?

    public func add() {
        
    }
    
    public func ls() {
        
    }

    public func rm() {
        
    }

}




public class Repo : ClientSubCommand {
    var parent: IpfsApiClient?
}

public class IPFSObject {
    
}

public class Swarm : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func peers(completionHandler: ([Multiaddr]) -> Void) throws {
        try parent!.fetchData("swarm/peers?stream-channels=true") {
            (data: NSData) in
            do {
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : [String]] else { throw IpfsApiError.JsonSerializationFailed
                }
                
                guard let stringsData = json["Strings"] else {
                    throw IpfsApiError.SwarmError("Swarm.peers error: No Strings key in JSON data.")
                }
                
                var addresses: [Multiaddr] = []
                for entry in stringsData as [String] {
                    addresses.append(try newMultiaddr(entry))
                }
                /// convert the data into a Multiaddr array and pass it to the handler
                completionHandler(addresses)
            } catch {
                print("Swarm peers error serializing JSON",error)
            }
        }
    }
    
    public func addrs(completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchData("swarm/addrs?stream-channels=true") {
            (data: NSData) in
            do {
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : AnyObject] else { throw IpfsApiError.JsonSerializationFailed
                }
                guard let addrsData = json["Addrs"] else {
                    throw IpfsApiError.SwarmError("Swarm.addrs error: No Addrs key in JSON data.")
                }
                completionHandler(addrsData as! [String : [String]])
            } catch {
                print("Swarm addrs error serializing JSON",error)
            }
        }
    }
    
    public func connect(multiAddr: String, completionHandler: (String) -> Void) throws {
        try parent!.fetchData("swarm/connect?arg="+multiAddr) {
            (data: NSData) in
            do {
                // Parse the data
                guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? [String : AnyObject] else { throw IpfsApiError.JsonSerializationFailed
                }
                /// Ensure we've only got one string as a result.
                guard let result = json["Strings"] where result.count == 1 else {
                    throw IpfsApiError.SwarmError("Swarm.connect error: No Strings key in JSON data.")
                }

                completionHandler(result[0] as! String)
            } catch {
                print("Swarm addrs error serializing JSON",error)
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

/** Deal with concatenated JSON (since JSONSerialization doesn't) by turning
 it into a string wrapping it in array brackets and comma separating the
 various root components. */
func fixStreamJson(rawJson: NSData) -> NSData {
    
    var newRes: NSData = NSMutableData()
    
    if let dataString = NSString(data: rawJson, encoding: NSUTF8StringEncoding) {
        
        var myStr = dataString as String
        myStr = myStr.stringByReplacingOccurrencesOfString("}", withString: "},")
        myStr = String(myStr.characters.dropLast())
        myStr = "[" + myStr + "]"
        newRes = myStr.dataUsingEncoding(NSUTF8StringEncoding)!
    }
    return newRes
}
