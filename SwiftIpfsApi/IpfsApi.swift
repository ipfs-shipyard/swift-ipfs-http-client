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
    
    var baseUrl:    String { get }
    
    /// Second Tier commands
    var refs:       Refs { get }
    var repo:       Repo { get }
    var block:      Block { get }
    var object:     IpfsObject { get }
    var name:       Name { get }
    var pin:        Pin { get }
    var swarm:      Swarm { get }
    var dht:        Dht { get }
    var bootstrap:  Bootstrap { get }
    var diag:       Diag { get }
    var stats:      Stats { get }
    var config:     Config { get }
    var update:     Update { get }
    
    var net:        NetworkIo { get }
}

protocol ClientSubCommand {
    var parent: IpfsApiClient? { get set }
}

extension ClientSubCommand {
    mutating func setParent(p: IpfsApiClient) { self.parent = p }
}

extension IpfsApiClient {
    
    func fetchStreamJson(   path: String,
                            updateHandler: (NSData, NSURLSessionDataTask) throws -> Bool,
                            completionHandler: (AnyObject) throws -> Void) throws {
        /// We need to use the passed in completionHandler
        try net.streamFrom(baseUrl + path, updateHandler: updateHandler, completionHandler: completionHandler)
    }
    
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
        
        try net.receiveFrom(baseUrl + path, completionHandler: completionHandler)
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
    case BootstrapError(String)
}

public class IpfsApi : IpfsApiClient {

    public var baseUrl: String = ""
    
    public let host: String
    public let port: Int
    public let version: String
    public let net: NetworkIo
    
    /// Second Tier commands
    public let refs       = Refs()
    public let repo       = Repo()
    public let block      = Block()
    public let object     = IpfsObject()
    public let name       = Name()
    public let pin        = Pin()
    public let swarm      = Swarm()
    public let dht        = Dht()
    public let bootstrap  = Bootstrap()
    public let diag       = Diag()
    public let stats      = Stats()
    public let config     = Config()
    public let update     = Update()

    
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
        
        /// No https yet as TLS1.2 in OS X 10.11 is not allowing comms with the node.
        baseUrl = "http://\(host):\(port)\(version)"
        net = HttpIo()
        
        /** All of IPFSApi's properties need to be set before we can use self which
            is why we can't just init the sub commands with self (unless we make 
            them var which makes them changeable by the user). */
        refs.parent       = self
        repo.parent       = self
        block.parent      = self
        pin.parent        = self
        swarm.parent      = self
        object.parent     = self
        name.parent       = self
        dht.parent        = self
        bootstrap.parent  = self
        diag.parent       = self
        stats.parent      = self
        config.parent     = self
        update.parent     = self
//        v This breaks the compiler so doing it the old fashioned way ^
//        /// set all the secondary commands' parent to this.
//        let secondary = [refs, repo, block, pin, swarm, object, name, dht, bootstrap, diags, stats]
//        secondary.map { (var s: ClientSubCommand) in s.setParent(self) }
    }
    
    
    /// base commands
    
    public func add(filePath: String, completionHandler: ([MerkleNode]) -> Void) throws {
        try self.add([filePath], completionHandler: completionHandler)
    }
    
    public func add(filePaths: [String], completionHandler: ([MerkleNode]) -> Void) throws {

        try net.sendTo(baseUrl+"add?stream-channels=true", content: filePaths) {
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
    
    /** ping is a tool to test sending data to other nodes. 
        It finds nodes via the routing system, send pings, wait for pongs, 
        and prints out round- trip latency information. */
    public func ping(target: String, completionHandler: ([[String : AnyObject]]) -> Void) throws {
        try fetchData("ping/" + target) {
            (rawJson: NSData) in
            
            /// Check for streamed JSON format and wrap & separate.
            let data = fixStreamJson(rawJson)
            
            guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? [[String : AnyObject]] else { throw IpfsApiError.JsonSerializationFailed
            }

            completionHandler(json)
        }
    }
    
    
    public func id(target: String? = nil, completionHandler: ([String : AnyObject]) -> Void) throws {
        var request = "id"
        if target != nil { request += "/\(target!)" }
        
        try fetchDictionary(request, completionHandler: completionHandler)
    }
    
    public func version(completionHandler: (String) -> Void) throws {
        try fetchDictionary("version") { json in
            let version = json["Version"] as? String ?? ""
            completionHandler(version)
        }
    }
    
    /** List all available commands. */
    public func commands(showOptions: Bool = false, completionHandler: ([String : AnyObject]) -> Void) throws {
        
        var request = "commands" //+ (showOptions ? "?flags=true&" : "")
        if showOptions { request += "?flags=true&" }
        
        try fetchDictionary(request, completionHandler: completionHandler)
    }
    
    /** This method should take both a completion handler and an update handler.
        Since the log tail won't stop until interrupted, the update handler
        should return false when it wants the updates to stop.
    */
    public func log(updateHandler: (NSData) throws -> Bool, completionHandler: ([[String : AnyObject]]) -> Void) throws {
        
        /// Two test closures to be passed to the fetchStreamJson as parameters.
        let comp = { (result: AnyObject) -> Void in
            completionHandler(result as! [[String : AnyObject]])
        }
            
        let update = { (data: NSData, task: NSURLSessionDataTask) -> Bool in
            
            let fixed = fixStreamJson(data)
            let json = try NSJSONSerialization.JSONObjectWithData(fixed, options: NSJSONReadingOptions.AllowFragments)
                
            if let arr = json as? [AnyObject] {
                for res in arr {
                    print(res)
                }
            } else {
                if let dict = json as? [String: AnyObject] {
                    print("It's a dict!:",dict )
                }
            }
            return true
        }
        
        try fetchStreamJson("log/tail", updateHandler: update, completionHandler: comp)
    }
}


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

/** IPNS is a PKI namespace, where names are the hashes of public keys, and
    the private key enables publishing new (signed) values. In both publish
    and resolve, the default value of <name> is your own identity public key.
*/
public class Name : ClientSubCommand {
 
   var parent: IpfsApiClient?
    
    public func publish(hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        try self.publish(nil, hash: hash, completionHandler: completionHandler)
    }
    
    public func publish(id: String? = nil, hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        var request = "name/publish?arg="
        if id != nil { request += id! + "&arg=" }
        try parent!.fetchDictionary(request + "/ipfs/" + b58String(hash), completionHandler: completionHandler)
    }

    public func resolve(hash: Multihash? = nil, completionHandler: (String) -> Void) throws {
        
        var request = "name/resolve"
        if hash != nil { request += "?arg=" + b58String(hash!) }
        
        try parent!.fetchData(request) {
            (rawJson: NSData) in
            print(rawJson)
            
            guard let json = try NSJSONSerialization.JSONObjectWithData(rawJson, options: NSJSONReadingOptions.AllowFragments) as? [String : AnyObject] else { throw IpfsApiError.JsonSerializationFailed
            }
            
            let resolvedName = json["Path"] as? String ?? ""
            completionHandler(resolvedName)
        }

    }
}

public class Dht : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func findProvs(hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/findprovs?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func query(address: Multiaddr, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/query?arg=" + address.string() , completionHandler: completionHandler)
    }
    
    public func findpeer(address: Multiaddr, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/findpeer?arg=" + address.string() , completionHandler: completionHandler)
    }
    
    public func get(hash: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/get?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    public func put(key: String, value: String, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("dht/put?arg=\(key)&arg=\(value)", completionHandler: completionHandler)
    }
}


public class File : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func ls(path: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("file/ls?arg=" + b58String(path), completionHandler: completionHandler)
    }
}

/** Show or edit the list of bootstrap peers */
extension IpfsApi {
    
    public func bootstrap(completionHandler: ([Multiaddr]) -> Void) throws {
        try bootstrap.list(completionHandler)
    }
}

/**
     SECURITY WARNING:
 
     The bootstrap command manipulates the "bootstrap list", which contains
     the addresses of bootstrap nodes. These are the *trusted peers* from
     which to learn about other peers in the network. Only edit this list
     if you understand the risks of adding or removing nodes from this list.
*/
public class Bootstrap : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    
    public func list(completionHandler: ([Multiaddr]) throws -> Void) throws {
        
        try parent!.fetchDictionary("bootstrap/") {
            jsonDictionary in
            
            var addresses: [Multiaddr] = []
            if let peers = jsonDictionary["Peers"] as? [String] {
                /// Make an array of Multiaddr from each peer
                addresses = try peers.map { try newMultiaddr($0) }
            }

            /// convert the data into a Multiaddr array and pass it to the handler
            try completionHandler(addresses)
        }
    }
    
    public func add(addresses: [Multiaddr], completionHandler: ([Multiaddr]) throws -> Void) throws {
        
        let multiaddresses = try addresses.map { try $0.string() }
        let request = "bootstrap/add?" + buildArgString(multiaddresses)
        
        print(request)
        
        try parent!.fetchDictionary(request) {
            jsonDictionary in
            
            var addresses: [Multiaddr] = []
            if let peers = jsonDictionary["Peers"] as? [String] {
                /// Make an array of Multiaddr from each peer
                addresses = try peers.map { try newMultiaddr($0) }
            }

            /// convert the data into a Multiaddr array and pass it to the handler
            try completionHandler(addresses)
        }
    }
    
    public func rm(addresses: [Multiaddr], completionHandler: ([Multiaddr]) throws -> Void) throws {
        
        try self.rm(addresses, all: false, completionHandler: completionHandler)
    }
    
    public func rm(addresses: [Multiaddr], all: Bool, completionHandler: ([Multiaddr]) throws -> Void) throws {
        
        let multiaddresses = try addresses.map { try $0.string() }
        var request = "bootstrap/rm?"
        
        if all { request += "all=true&" }
        
        request += buildArgString(multiaddresses)
        
        try parent!.fetchDictionary(request) {
            jsonDictionary in
            
            var addresses: [Multiaddr] = []
            if let peers = jsonDictionary["Peers"] as? [String] {
                /// Make an array of Multiaddr from each peer
                addresses = try peers.map { try newMultiaddr($0) }
            }

            /// convert the data into a Multiaddr array and pass it to the handler
            try completionHandler(addresses)
        }
    }
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
            
            var addresses: [Multiaddr] = []
            if let swarmPeers = jsonDictionary["Strings"] as? [String] {
                /// Make an array of Multiaddr from each peer in swarmPeers.
                addresses = try swarmPeers.map { try newMultiaddr($0) }
            }

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

/** Generates diagnostic reports */
public class Diag : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    /** Generates a network diagnostics report */
    public func net(completionHandler: (String) -> Void) throws {
        try parent!.fetchBytes("diag/net?stream-channels=true") {
            bytes in
            completionHandler(String(bytes: bytes, encoding: NSUTF8StringEncoding)!)
        }
    }
    
    /* Prints out system diagnostic information. */
    public func sys(completionHandler: (String) -> Void) throws {
        try parent!.fetchBytes("diag/sys?stream-channels=true") {
            bytes in
            completionHandler(String(bytes: bytes, encoding: NSUTF8StringEncoding)!)
        }
    }
}

/** Config controls configuration variables. It works much like 'git config'. 
    The configuration values are stored in a config file inside your IPFS repository.
*/
public class Config : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func show(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("config/show",completionHandler: completionHandler )
    }
    
    public func replace(filePath: String, completionHandler: (Bool) -> Void) throws {
        try parent!.net.sendTo(parent!.baseUrl+"config/replace?stream-channels=true", content: [filePath]) {
            _ in
        }
    }
    
    public func get(key: String, completionHandler: (JsonType) throws -> Void) throws {
        try parent!.fetchDictionary("config?arg=" + key) {
            (jsonDictionary: Dictionary) in
            
            guard let result = jsonDictionary["Value"] else {
                throw IpfsApiError.SwarmError("Config get error: \(jsonDictionary["Message"] as? String)")
            }
            
            try completionHandler(JsonType.parse(result))
            
        }
    }
    
    public func set(key: String, value: String, completionHandler: ([String : AnyObject]) throws -> Void) throws {
        
        try parent!.fetchDictionary("config?arg=\(key)&arg=\(value)", completionHandler: completionHandler )
    }
}

/** Downloads and installs updates for IPFS (disabled at the API node side) */
extension Update{
    
    public func update(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("update", completionHandler: completionHandler )
    }
}

public class Update : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func check(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("update/check", completionHandler: completionHandler )
    }
    
    public func log(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        try parent!.fetchDictionary("update/log", completionHandler: completionHandler )
    }
}



public class Stats : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    /** Print ipfs bandwidth information. Currently ignores flags.*/
    public func bw( peer: String? = nil,
                    proto: String? = nil,
                    poll: Bool = false,
                    interval: String? = nil,
                    completionHandler: ([String : AnyObject]) -> Void) throws {
                        
        try parent!.fetchDictionary("stats/bw", completionHandler: completionHandler)
    }
}



/// Utility functions

/** Deal with concatenated JSON (since JSONSerialization doesn't) by wrapping it
 in array brackets and comma separating the various root components. */
public func fixStreamJson(rawJson: NSData) -> NSData {
    /// get the bytes
    let bytes            = UnsafePointer<UInt8>(rawJson.bytes)
    var sections         = 0
    var brackets         = 0
    var bytesRead        = 0
    let output           = NSMutableData()
    var newStart         = bytes
    /// Start the output off with a JSON opening array bracket [.
    output.appendBytes([91] as [UInt8], length: 1)
    
    for var i=0; i < rawJson.length ; i++ {
        switch bytes[i] {

        case 91 where sections == 0:      /// If an [ is first we need no fix
            return rawJson

        case 123 where ++brackets == 1:   /// check for {
            newStart = bytes+i
            
        case 125 where --brackets == 0:   /// Check for }
            
            /// Separate sections with a comma except the first one.
            if output.length > 1 {
                output.appendBytes([44] as [UInt8], length: 1)
            }
            
            output.appendData(NSData(bytes: newStart, length: bytesRead+1))
            bytesRead = 0
            sections++

        default:
            break
        }
        
        if brackets > 0 { bytesRead++ }
    }
    
    /// There was nothing to fix. Bail.
    if sections == 1 { return rawJson }
    
    /// End the output with a JSON closing array bracket ].
    output.appendBytes([93] as [UInt8], length: 1)
    
    return output
}


func buildArgString(args: [String]) -> String {
    var outString = ""
    for arg in args {
        outString += "arg=\(arg.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)&"
    }
    return outString
}

