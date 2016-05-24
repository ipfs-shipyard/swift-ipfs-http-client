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
    var file:       File { get }
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
    

    func fetchJson(path: String, completionHandler: (JsonType) throws -> Void) throws {
        try fetchData(path) {
            (data: NSData) in

            /// If there was no data fetched pass an empty dictionary and return.
            if data.length == 0 {
                try completionHandler(JsonType.Null)
                return
            }
//            print(data)
            let fixedData = fixStreamJson(data)
            let json = try NSJSONSerialization.JSONObjectWithData(fixedData, options: NSJSONReadingOptions.AllowFragments)
    
            /// At this point we could check to see if the json contains a code/message for flagging errors.
            
            try completionHandler(JsonType.parse(json))
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
    case ResultMissingData(String)
    case UnexpectedReturnType
    
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
    public let file       = File()
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
        file.parent       = self
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
            data in
            do {
                /// If there was no data fetched pass an empty dictionary and return.
                let fixedData = fixStreamJson(data)
                let json = JsonType.parse(try NSJSONSerialization.JSONObjectWithData(fixedData, options: NSJSONReadingOptions.AllowFragments))
                
                switch json {
                case .Object:
                    completionHandler([try merkleNodeFromJson2(json)])
                case .Array:
                    completionHandler(try json.array!.map { try merkleNodeFromJson2($0) })
                default:
                    throw IpfsApiError.JsonSerializationFailed
                }
            } catch {
                print("Error inside add completion handler: \(error)")
            }
        }
    }
    
    public func ls(hash: Multihash, completionHandler: ([MerkleNode]) -> Void) throws {
        
        try fetchJson("ls/\(b58String(hash))") {
            json in
            
            guard let objects = json.object?["Objects"]?.array else {
                throw IpfsApiError.SwarmError("ls error: No Objects in JSON data.")
            }
            
            let merkles = try objects.map { try merkleNodeFromJson2($0) }
            
            completionHandler(merkles)
        }
    }

    public func cat(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        try fetchBytes("cat/\(b58String(hash))", completionHandler: completionHandler)
    }
    
    public func get(hash: Multihash, completionHandler: ([UInt8]) -> Void) throws {
        try self.cat(hash, completionHandler: completionHandler)
    }


    public func refs(hash: Multihash, recursive: Bool, completionHandler: ([Multihash]) -> Void) throws {
        
        try fetchJson("refs?arg=" + b58String(hash) + "&r=\(recursive)") {
           result in
        
            guard let results = result.array else { throw IpfsApiError.UnexpectedReturnType }
            /// Extract the references and add them to an array.
            var refs: [Multihash] = []
            for obj in results {
                if let ref = obj.object?["Ref"]?.string {
                    let mh = try fromB58String(ref)
                    refs.append(mh)
                }
            }
            
            completionHandler(refs)
        }
    }
    public func resolve(scheme: String, hash: Multihash, recursive: Bool, completionHandler: (JsonType) -> Void) throws {
        try fetchJson("resolve?arg=/\(scheme)/\(b58String(hash))&r=\(recursive)", completionHandler: completionHandler)
    }
    
    public func dns(domain: String, completionHandler: (String) -> Void) throws {
        try fetchJson("dns?arg=" + domain) {
            result in
            
                guard let path = result.object?["Path"]?.string else { throw IpfsApiError.ResultMissingData("No Path found") }
                completionHandler(path)
        }
    }
    
    public func mount(ipfsRootPath: String = "/ipfs", ipnsRootPath: String = "/ipns", completionHandler: (JsonType) -> Void) throws {
        
        let fileManager = NSFileManager.defaultManager()
        
        /// Create the directories if they do not already exist.
        if fileManager.fileExistsAtPath(ipfsRootPath) == false {
            try fileManager.createDirectoryAtPath(ipfsRootPath, withIntermediateDirectories: false, attributes: nil)
        }
        if fileManager.fileExistsAtPath(ipnsRootPath) == false {
            try fileManager.createDirectoryAtPath(ipnsRootPath, withIntermediateDirectories: false, attributes: nil)
        }
        
        try fetchJson("mount?arg=" + ipfsRootPath + "&arg=" + ipnsRootPath, completionHandler: completionHandler)
    }
    
    /** ping is a tool to test sending data to other nodes. 
        It finds nodes via the routing system, send pings, wait for pongs, 
        and prints out round- trip latency information. */
    public func ping(target: String, completionHandler: (JsonType) -> Void) throws {
        try fetchJson("ping/" + target, completionHandler: completionHandler)
    }
    
    
    public func id(target: String? = nil, completionHandler: (JsonType) -> Void) throws {
        var request = "id"
        if target != nil { request += "/\(target!)" }
        
        try fetchJson(request, completionHandler: completionHandler)
    }
    
    public func version(completionHandler: (String) -> Void) throws {
        try fetchJson("version") {
            json in
            let version = json.object?["Version"]?.string ?? ""
            completionHandler(version)
        }
    }
    
    /** List all available commands. */
    public func commands(showOptions: Bool = false, completionHandler: (JsonType) -> Void) throws {
        
        var request = "commands" //+ (showOptions ? "?flags=true&" : "")
        if showOptions { request += "?flags=true&" }
        
        try fetchJson(request, completionHandler: completionHandler)
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



/** Show or edit the list of bootstrap peers */
extension IpfsApiClient {
    
    public func bootstrap(completionHandler: ([Multiaddr]) -> Void) throws {
        try bootstrap.list(completionHandler)
    }
}


/** Downloads and installs updates for IPFS (disabled at the API node side) */
extension IpfsApiClient {
    
    public func update(completionHandler: ([String : AnyObject]) -> Void) throws {
        
        //try update.fetchDictionary("update", completionHandler: completionHandler )
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
    
    //for var i=0; i < rawJson.length ; i++ {
    for i in 0..<rawJson.length {
        switch bytes[i] {

        case 91 where sections == 0:      /// If an [ is first we need no fix
            return rawJson

//        case 123 where ++brackets == 1:   /// check for {
        case 123:
            brackets += 1
            if brackets == 1 { newStart = bytes+i }
            
//        case 125 where --brackets == 0:   /// Check for }
        case 125:
            brackets -= 1
            if brackets == 0 {
                /// Separate sections with a comma except the first one.
                if output.length > 1 {
                    output.appendBytes([44] as [UInt8], length: 1)
                }
                
                output.appendData(NSData(bytes: newStart, length: bytesRead+1))
                bytesRead = 0
                sections += 1
            }
//            sections++

        default:
            break
        }
        
        if brackets > 0 { bytesRead += 1 } //bytesRead++ }
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

