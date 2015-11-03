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

/// This is to allow a Multihash to be used as a Dictionary key.
extension Multihash : Hashable {
    public var hashValue: Int {
        return String(value).hash
    }
}

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

            /// If there was no data fetched pass an empty dictionary and return.
            if data.length == 0 {
                try completionHandler([:])
                return
            }
            //print(data)
    
            guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? [String : AnyObject] else { throw IpfsApiError.JsonSerializationFailed
            }
    
            /// At this point we could check to see if the json contains a code/message for flagging errors.
            
            try completionHandler(json)
        }
    }
    
    func fetchData(path: String, completionHandler: (NSData) throws -> Void) throws {
        
        let fullUrl = baseUrl + path
        print("url",fullUrl)
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
    
    func fetchBytes(path: String, completionHandler: ([UInt8]) throws -> Void) throws {
        try fetchData(path) {
            (data: NSData) in
            
            /// Convert the data to a byte array
            let count = data.length / sizeof(UInt8)
            // create an array of Uint8
            var bytes = [UInt8](count: count, repeatedValue: 0)
            
            // copy bytes into array
            data.getBytes(&bytes, length:count * sizeof(UInt8))
            
            try completionHandler(bytes)
        }
    }
}

public enum PinType: String {
    case All       = "all"
    case Direct    = "direct"
    case Indirect  = "indirect"
    case Recursive = "recursive"
}

enum IpfsApiError : ErrorType {
    case InitError
    case InvalidUrl
    case NilData
    case DataTaskError(NSError)
    case JsonSerializationFailed
 
    case SwarmError(String)
    case RefsError(String)
    case PinError(String)
    case IpfsObjectError(String)
}

public class IpfsApi : IpfsApiClient {

    public var baseUrl: String = ""
    
    public let host: String
    public let port: Int
    public let version: String
    
    /// Second Tier commands
    public let refs       = Refs()
    public let repo       = Repo()
    public let block      = Block()
    public let object     = IpfsObject()
    public let pin        = Pin()
    public let swarm      = Swarm()


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
            is why we can't just init the sub commands with self (unless we make 
            them var which makes them changeable by the user). */
        refs.parent       = self
        repo.parent       = self
        block.parent      = self
        pin.parent        = self
        swarm.parent      = self
        object.parent     = self
    }
    
    
    /// base commands
    
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
                let merkles = try json.map { return try merkleNodeFromJson($0) }
                
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
                
                let merkles = try objects.map { try merkleNodeFromJson($0) }
                
                completionHandler(merkles)
            } catch {
                print("ls Error")
            }
        }
    }
    

    public func cat(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        let hashString = b58String(hash)
        try fetchBytes("cat/"+hashString, completionHandler: completionHandler)
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
    
    public func mount(ipfsRootPath: String = "/ipfs", ipnsRootPath: String = "/ipns", completionHandler: ([String : AnyObject]) -> Void) throws {
        
        let fileManager = NSFileManager.defaultManager()
        
        /// Create the directories if they do not already exist.
        if fileManager.fileExistsAtPath(ipfsRootPath) == false {
            try fileManager.createDirectoryAtPath(ipfsRootPath, withIntermediateDirectories: false, attributes: nil)
        }
        if fileManager.fileExistsAtPath(ipnsRootPath) == false {
            try fileManager.createDirectoryAtPath(ipnsRootPath, withIntermediateDirectories: false, attributes: nil)
        }
        
        /// 
        try fetchDictionary("mount?arg=" + ipfsRootPath + "&arg=" + ipnsRootPath) {
            (jsonDictionary: Dictionary) in
            
            completionHandler(jsonDictionary)
        }
    }
}


/// Move these to own file


public class Refs : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func local(completionHandler: ([Multihash]) -> Void) throws {
        try parent!.fetchData("refs/local") {
            (data: NSData) in

            /// First we turn the data into a string
            guard let dataString = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else {
                throw IpfsApiError.RefsError("Could not convert data into string.")
            }
            
            /** The resulting string is a bunch of newline separated strings so:
                1) Split the string up by the separator into a subsequence,
                2) Map each resulting subsequence into a string,
                3) Map each string into a Multihash with fromB58String. */
            let multiaddrs = try dataString.characters.split{$0 == "\n"}.map(String.init).map{ try fromB58String($0) }

            completionHandler(multiaddrs)
        }
    }
}

/** Pinning an object will ensure a local copy is not garbage collected. */
public class Pin : ClientSubCommand {
    
    var parent: IpfsApiClient?

    public func add(hash: Multihash, completionHandler: ([Multihash]) -> Void) throws {
        
        let hashString = b58String(hash)
        try parent!.fetchDictionary("pin/add?stream-channels=true&arg=" + hashString) {
            (jsonDictionary: Dictionary) in
            
            guard let objects = jsonDictionary["Pinned"] as? [AnyObject] else {
                throw IpfsApiError.PinError("Pin.add error: No Pinned objects in JSON data.")
            }
            
            let multihashes = try objects.map { try fromB58String($0 as! String) }

            completionHandler(multihashes)
        }
    }
    
    public func ls(completionHandler: ([Multihash : AnyObject]) -> Void) throws {
        
        /// The default is .Recursive
        try self.ls(.Recursive) {
            (result: [String : AnyObject]) throws -> Void in
            
            ///turn the result into a [Multihash : AnyObject]
            var multihashes: [Multihash : AnyObject] = [:]
            for (k,v) in result {
                multihashes[try fromB58String(k)] = v
            }
            
            completionHandler(multihashes)
        }
    }
    
    public func ls(pinType: PinType, completionHandler: ([String : AnyObject]) throws -> Void) throws {
        
        try parent!.fetchDictionary("pin/ls?stream-channels=true&t=" + pinType.rawValue) {
            (jsonDictionary: Dictionary) in
            
            guard let objects = jsonDictionary["Keys"] as? [String : AnyObject] else {
                throw IpfsApiError.PinError("Pin.ls error: No Keys Dictionary in JSON data.")
            }
            
            try completionHandler(objects)
        }
    }

    public func rm(hash: Multihash, completionHandler: ([Multihash]) -> Void) throws {
        try self.rm(hash, recursive: true, completionHandler: completionHandler)
    }
    
    public func rm(hash: Multihash, recursive: Bool, completionHandler: ([Multihash]) -> Void) throws {
        
        let hashString = b58String(hash)
        try parent!.fetchDictionary("pin/rm?stream-channels=true&r=\(recursive)&arg=\(hashString)") {
            (jsonDictionary: Dictionary) in
            
            guard let objects = jsonDictionary["Pinned"] as? [AnyObject] else {
                throw IpfsApiError.PinError("Pin.rm error: No Pinned objects in JSON data.")
            }
            
            let multihashes = try objects.map { try fromB58String($0 as! String) }
            
            completionHandler(multihashes)
        }
    }

}




public class Repo : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    /** gc is a plumbing command that will sweep the local set of stored objects 
     and remove ones that are not pinned in order to reclaim hard disk space. */
    public func gc(completionHandler: ([[String : AnyObject]]) -> Void) throws {
        try parent!.fetchData("repo/gc") {
            (rawJson: NSData) in
            
            /// Check for streamed JSON format and wrap & separate.
            let data = fixStreamJson(rawJson)
            
            guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? [[String : AnyObject]] else { throw IpfsApiError.JsonSerializationFailed
            }

            completionHandler(json)
        }
    }
}

public class Block {

    var parent: IpfsApiClient?
    
    public func get(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        let hashString = b58String(hash)
        try parent!.fetchBytes("block/get?stream-channels=true&arg=" + hashString, completionHandler: completionHandler)
    }
    
    public func put(data: [UInt8], completionHandler: (MerkleNode) -> Void) throws {
        let data2 = NSData(bytes: data, length: data.count)
        
        try HttpIo.sendTo(parent!.baseUrl+"block/put?stream-channels=true", content: data2) {
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

public class IpfsObject {
    
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
        try parent!.fetchDictionary(request) {
            (result: [String : AnyObject]) in
                
            try completionHandler( try merkleNodeFromJson(result as AnyObject) )
        }
    }
    
    /** IpfsObject put is a plumbing command for storing DAG nodes.
        Its input is a byte array, and the output is a base58 encoded multihash.
    */
    public func put(data: [UInt8], completionHandler: (MerkleNode) -> Void) throws {
        let data2 = NSData(bytes: data, length: data.count)
        
        try HttpIo.sendTo(parent!.baseUrl+"object/put?stream-channels=true", content: data2) {
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
     
        try parent!.fetchDictionary("object/get?stream-channels=true&arg=" + b58String(hash)){
            (var result) in
            result["Hash"] = b58String(hash)
            completionHandler(try merkleNodeFromJson(result))
        }
    }

    public func links(hash: Multihash, completionHandler: (MerkleNode) throws -> Void) throws {
        
        try parent!.fetchDictionary("object/links?stream-channels=true&arg=" + b58String(hash)){
            result in
            try completionHandler(try merkleNodeFromJson(result))
        }
    }
    
    public func stat(hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("object/stat?stream-channels=true&arg=" + b58String(hash), completionHandler: completionHandler)
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
    
        try parent!.fetchDictionary(request) {
            result in
            try completionHandler(try merkleNodeFromJson(result))
        }
    }
}

func buildArgString(args: [String]) -> String {
    var outString = ""
    for arg in args {
        outString += "arg=\(arg.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)&"
    }
    return outString
}

public class Swarm : ClientSubCommand {
    
    var parent: IpfsApiClient?

    /** peers lists the set of peers this node is connected to. 
        The completionHandler is passed an array of Multiaddr that represent 
        the peers.
     */
    public func peers(completionHandler: ([Multiaddr]) -> Void) throws {
        try parent!.fetchDictionary("swarm/peers?stream-channels=true") {
            (jsonDictionary: Dictionary) in
            
            guard let swarmPeers = jsonDictionary["Strings"] as? [String] else {
                throw IpfsApiError.SwarmError("Swarm.peers error: No Strings key in JSON data.")
            }

            /// Make an array of Multiaddr from each peer in swarmPeers.
            let addresses = try swarmPeers.map { try newMultiaddr($0) }
            /// convert the data into a Multiaddr array and pass it to the handler
            completionHandler(addresses)
        }
    }

    public func addrs(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("swarm/addrs?stream-channels=true") {
            (jsonDictionary: Dictionary) in
            
            guard let addrsData = jsonDictionary["Addrs"] as? [String : [String]] else {
                throw IpfsApiError.SwarmError("Swarm.addrs error: No Addrs key in JSON data.")
            }
            completionHandler(addrsData)
        }
    }
    public func connect(multiAddr: String, completionHandler: (String) -> Void) throws {
        try parent!.fetchDictionary("swarm/connect?arg="+multiAddr) {
            (jsonDictionary: Dictionary) in
            
            /// Ensure we've only got one string as a result.
            guard let result = jsonDictionary["Strings"] as? [String] where result.count == 1 else {
                throw IpfsApiError.SwarmError("Swarm.connect error: \(jsonDictionary["Message"] as? String)")
            }
            /// Consider returning the dictionary instead...
            completionHandler(result[0])
        }
    }
    
    public func disconnect(multiaddr: String, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("swarm/disconnect?arg=" + multiaddr) {
            (jsonDictionary: Dictionary) in
            completionHandler(jsonDictionary)
        }
    }
}

public struct Bootstrap {
    
}



public struct Diag {
    
}

public struct Config {
    
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

/** Deal with concatenated JSON (since JSONSerialization doesn't) by wrapping it
    in array brackets and comma separating the various root components. */
public func fixStreamJson(rawJson: NSData) -> NSData {
    /// get the bytes
    let bytes            = UnsafePointer<UInt8>(rawJson.bytes)
    var brackets         = 0
    var bytesRead        = 0
    let output           = NSMutableData()
    var newStart = bytes
    /// Start the output off with a JSON opening array bracket [.
    var tmpChar: [UInt8] = [91]
    output.appendBytes(tmpChar, length: 1)
    
    for var i=0; i < rawJson.length ; i++ {
        switch bytes[i] {
            case 123: brackets++
            case 125: brackets--
            default: break
        }
        //print(bytes[i])
        
        if brackets > 0 { bytesRead++ }
        if brackets == 0 && bytesRead++ != 0 {
            
            /// Separate sections with a comma unless it's the first one.
            if output.length > 1 {
                tmpChar = [44]
                output.appendBytes(tmpChar, length: 1)
            }
            
            output.appendData(NSData(bytes: newStart, length: bytesRead))
            newStart += bytesRead
            bytesRead = 0
            
        }
        
    }
    
    /// End the output with a JSON closing array bracket ].
    tmpChar = [93]
    output.appendBytes(tmpChar, length: 1)

    return output
}
/** Deal with concatenated JSON (since JSONSerialization doesn't) by turning
 it into a string wrapping it in array brackets and comma separating the
 various root components. */
func deprecatedfixStreamJson(rawJson: NSData) -> NSData {
    
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
