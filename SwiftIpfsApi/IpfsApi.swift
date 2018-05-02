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
        return String(describing: value).hash
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
    mutating func setParent(_ p: IpfsApiClient) { self.parent = p }
}

extension IpfsApiClient {
    
    func fetchStreamJson(   _ path: String,
                            updateHandler: @escaping (Data, URLSessionDataTask) throws -> Bool,
                            completionHandler: @escaping (AnyObject) throws -> Void) throws {
        /// We need to use the passed in completionHandler
        try net.streamFrom(baseUrl + path, updateHandler: updateHandler, completionHandler: completionHandler)
    }
	
	
//	let stream: InputStream = InputStream(data: data)
//	var buffer = [UInt8](repeating: 0, count: data.count)
//	stream.open()
//	
//	if stream.hasBytesAvailable {
//	//let result :Int = stream.read(&buffer, maxLength: buffer.count)
//	let myson = try JSONSerialization.jsonObject(with: stream)
//	print("streams \(myson)")
//	}
//	stream.close()
	
	
    func fetchJson(_ path: String, completionHandler: @escaping (JsonType) throws -> Void) throws {
        try fetchData(path) {
            (data: Data) in

            /// If there was no data fetched pass an empty dictionary and return.
            if data.count == 0 {
                try completionHandler(JsonType.null)
                return
            }

            print("The data:",NSString(data: data, encoding: String.Encoding.utf8.rawValue))
            let fixedData: Data = fixStreamJson(data)
            print("The fixed data:",NSString(data: fixedData, encoding: String.Encoding.utf8.rawValue))
			
			var json: Any
			do {
				json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
			} catch {
				/// So the serialization might have failed due to the json being concatenated.
				/// Let's try fixing it
				let fixedData: Data = fixStreamJson(data)
				/// and try again
				json = try JSONSerialization.jsonObject(with: fixedData, options: JSONSerialization.ReadingOptions.allowFragments)
			}
            /// At this point we could check to see if the json contains a code/message for flagging errors.
            
            try completionHandler(JsonType.parse(json as AnyObject))
        }
    }
    
    func fetchData(_ path: String, completionHandler: @escaping (Data) throws -> Void) throws {
        
        try net.receiveFrom(baseUrl + path, completionHandler: completionHandler)
    }
    
    func fetchBytes(_ path: String, completionHandler: @escaping ([UInt8]) throws -> Void) throws {
        try fetchData(path) {
            (data: Data) in
            
            /// Convert the data to a byte array
            let count = data.count / MemoryLayout<UInt8>.size
            // create an array of Uint8
            var bytes = [UInt8](repeating: 0, count: count)
            
            // copy bytes into array
            (data as NSData).getBytes(&bytes, length:count * MemoryLayout<UInt8>.size)
            
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

enum IpfsApiError : Error {
    case initError
    case invalidUrl
    case nilData
    case dataTaskError(NSError)
    case jsonSerializationFailed
    case resultMissingData(String)
    case unexpectedReturnType
    
    case swarmError(String)
    case refsError(String)
    case pinError(String)
    case ipfsObjectError(String)
    case bootstrapError(String)
}

// map command names to string to avoid "stringly typed" lookups.
enum IpfsCmdString : String {
    case Ref     = "Ref"
    case Path    = "Path"
    case Version = "Version"
    case Name    = "Name"
    case Keys    = "Keys"
    case Peers   = "Peers"
    case ID      = "ID"
    case Addrs   = "Addrs"
    case Value   = "Value"
    case Message = "Message"
    
}

public class IpfsApi : IpfsApiClient {

    public var baseUrl: String = ""
    
    public let scheme: String
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
        var protoComponents = addressString.split{$0 == "/"}.map(String.init)
        if  protoComponents[0].hasPrefix("ip") == true &&
            protoComponents[2].hasPrefix("tcp") == true {
                
            try self.init(host: protoComponents[1],port: Int(protoComponents[3])!)
        } else {
            throw IpfsApiError.initError
        }
    }

    public convenience init(addr: String) throws {
        try self.init(addr: newMultiaddr(addr))
    }

    public init(host: String, port: Int, version: String = "/api/v0/", ssl: Bool = false) throws {
        self.scheme = ssl ? "https://" : "http://"
        self.host = host
        self.port = port
        self.version = version
        
        
        /// No https yet as TLS1.2 in OS X 10.11 is not allowing comms with the node.
        baseUrl = "\(scheme)\(host):\(port)\(version)"
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
    
    public func add(_ filePath: String, completionHandler: @escaping ([MerkleNode]) -> Void) throws {
        
        try net.sendTo(baseUrl+"add?s", filePath: filePath) {
            data in
            do {
                /// If there was no data fetched pass an empty dictionary and return.
                let fixedData = fixStreamJson(data)
                
                let json = JsonType.parse(try JSONSerialization.jsonObject(with: fixedData, options: JSONSerialization.ReadingOptions.allowFragments) as AnyObject)
                
                let res = try merkleNodesFromJson(json)
                guard res.count > 0 else { throw IpfsApiError.jsonSerializationFailed }
                
                /// Unwrap optionals
                let result = res.compactMap{ $0 }
                
                completionHandler( result )
                
            } catch {
                print("Error inside add completion handler: \(error)")
            }
        }
    }
    
    // Store binary data
    
    public func add(_ fileData: Data, completionHandler: @escaping ([MerkleNode]) -> Void) throws {
        
        try net.sendTo(baseUrl+"add?stream-channels=true", content: fileData) {
            data in
            do {
                /// If there was no data fetched pass an empty dictionary and return.
                let fixedData = fixStreamJson(data)
                
                
                let json = JsonType.parse(try JSONSerialization.jsonObject(with: fixedData, options: JSONSerialization.ReadingOptions.allowFragments) as AnyObject)
                print(json)
                
                let res = try merkleNodesFromJson(json)
                guard res.count > 0 else { throw IpfsApiError.jsonSerializationFailed }
                
                /// Unwrap optionals
                let result = res.compactMap{ $0 }
                
                completionHandler( result )
                
            } catch {
                print("Error inside add completion handler: \(error)")
            }
        }
    }
    
    public func ls(_ hash: Multihash, completionHandler: @escaping ([MerkleNode]) -> Void) throws {
        
        try fetchJson("ls/\(b58String(hash))") {
            json in
            
            guard let objects = json.object?["Objects"]?.array else {
                throw IpfsApiError.swarmError("ls error: No Objects in JSON data.")
            }
            
            let merkles = try objects.map { try merkleNodeFromJson2($0) }
//            let tmp = try merkleNodesFromJson(json)
            /// Unwrap optionals
//            let merkles = tmp.flatMap{ $0 }

            completionHandler(merkles)
        }
    }

    public func cat(_ hash: Multihash, completionHandler: @escaping ([UInt8]) -> Void) throws {
        try fetchBytes("cat/\(b58String(hash))", completionHandler: completionHandler)
    }
    
    public func get(_ hash: Multihash, completionHandler: @escaping ([UInt8]) -> Void) throws {
        try self.cat(hash, completionHandler: completionHandler)
    }


    public func refs(_ hash: Multihash, recursive: Bool, completionHandler: @escaping ([Multihash]) -> Void) throws {
        
        try fetchJson("refs?arg=" + b58String(hash) + "&r=\(recursive)") {
			result in
            guard let results = result.array else { throw IpfsApiError.unexpectedReturnType }
            /// Extract the references and add them to an array.
            var refs: [Multihash] = []
			
            for obj in results {
                if let ref = obj.object?[IpfsCmdString.Ref.rawValue]?.string {
                    let mh = try fromB58String(ref)
                    refs.append(mh)
                }
            }
            
            completionHandler(refs)
        }
    }

    public func resolve(_ scheme: String, hash: Multihash, recursive: Bool, completionHandler: @escaping (JsonType) -> Void) throws {
        try fetchJson("resolve?arg=/\(scheme)/\(b58String(hash))&r=\(recursive)", completionHandler: completionHandler)
    }
    
    public func dns(_ domain: String, completionHandler: @escaping (String) -> Void) throws {
        try fetchJson("dns?arg=" + domain) {
            result in
            
                guard let path = result.object?[IpfsCmdString.Path.rawValue]?.string else { throw IpfsApiError.resultMissingData("No Path found") }
                completionHandler(path)
        }
    }
    
    public func mount(_ ipfsRootPath: String = "/ipfs", ipnsRootPath: String = "/ipns", completionHandler: @escaping (JsonType) -> Void) throws {
        
        let fileManager = FileManager.default
        
        /// Create the directories if they do not already exist.
        if fileManager.fileExists(atPath: ipfsRootPath) == false {
            try fileManager.createDirectory(atPath: ipfsRootPath, withIntermediateDirectories: false, attributes: nil)
        }
        if fileManager.fileExists(atPath: ipnsRootPath) == false {
            try fileManager.createDirectory(atPath: ipnsRootPath, withIntermediateDirectories: false, attributes: nil)
        }
        
        try fetchJson("mount?arg=" + ipfsRootPath + "&arg=" + ipnsRootPath, completionHandler: completionHandler)
    }
    
    /** ping is a tool to test sending data to other nodes. 
        It finds nodes via the routing system, send pings, wait for pongs, 
        and prints out round- trip latency information. */
    public func ping(_ target: String, completionHandler: @escaping (JsonType) -> Void) throws {
        try fetchJson("ping/" + target, completionHandler: completionHandler)
    }
    
    
    public func id(_ target: String? = nil, completionHandler: @escaping (JsonType) -> Void) throws {
        var request = "id"
        if target != nil { request += "/\(target!)" }
        
        try fetchJson(request, completionHandler: completionHandler)
    }
    
    public func version(_ completionHandler: @escaping (String) -> Void) throws {
        try fetchJson("version") {
            json in
            let version = json.object?[IpfsCmdString.Version.rawValue]?.string ?? ""
            completionHandler(version)
        }
    }
    
    /** List all available commands. */
    public func commands(_ showOptions: Bool = false, completionHandler: @escaping (JsonType) -> Void) throws {
        
        var request = "commands" //+ (showOptions ? "?flags=true&" : "")
        if showOptions { request += "?flags=true&" }
        
        try fetchJson(request, completionHandler: completionHandler)
    }
    
    /** This method should take both a completion handler and an update handler.
        Since the log tail won't stop until interrupted, the update handler
        should return false when it wants the updates to stop.
    */
    public func log(_ updateHandler: (Data) throws -> Bool, completionHandler: @escaping ([[String : AnyObject]]) -> Void) throws {
        
        /// Two test closures to be passed to the fetchStreamJson as parameters.
        let comp = { (result: AnyObject) -> Void in
            completionHandler(result as! [[String : AnyObject]])
        }
            
        let update = { (data: Data, task: URLSessionDataTask) -> Bool in
            
            let fixed = fixStreamJson(data)
            let json = try JSONSerialization.jsonObject(with: fixed, options: JSONSerialization.ReadingOptions.allowFragments)
                
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
    
    public func bootstrap(_ completionHandler: @escaping ([Multiaddr]) -> Void) throws {
        try bootstrap.list(completionHandler)
    }
}


/** Downloads and installs updates for IPFS (disabled at the API node side) */
extension IpfsApiClient {
    
    public func update(_ completionHandler: ([String : AnyObject]) -> Void) throws {
        
        //try update.fetchDictionary("update", completionHandler: completionHandler )
    }
}


/// Utility functions

/** Deal with concatenated JSON (since JSONSerialization doesn't) by wrapping it
 in array brackets and comma separating the various root components. */
public func fixStreamJson(_ rawJson: Data) -> Data {

    var sections         = 0
    var brackets         = 0
    var bytesRead        = 0
    let output           = NSMutableData()

    rawJson.withUnsafeBytes { (bytes: UnsafePointer<UInt8>)->Void in
        
        var newStart         = bytes
        /// Start the output off with a JSON opening array bracket [.
        output.append([91] as [UInt8], length: 1)
        
        for i in 0 ..< rawJson.count {
            switch bytes[i] {

            case 91 where sections == 0:      /// If an [ is first we need no fix
                sections = 1
                return// rawJson

            case 123 where (brackets+1) == 1:   /// check for {
                brackets += 1
                newStart = bytes+i
                
            case 125 where (brackets-1) == 0:   /// Check for }
                brackets -= 1
                /// Separate sections with a comma except the first one.
                if output.length > 1 {
                    output.append([44] as [UInt8], length: 1)
                }
                
                output.append(Data(bytes: UnsafePointer<UInt8>(newStart), count: bytesRead+1))
                bytesRead = 0
                sections += 1

            default:
                break
            }
            
            if brackets > 0 { bytesRead += 1 }
        }
    }
    /// There was nothing to fix. Bail.
    if sections == 1 { return rawJson }
    
    /// End the output with a JSON closing array bracket ].
    output.append([93] as [UInt8], length: 1)
    
    return output as Data
}


func buildArgString(_ args: [String]) -> String {
    var outString = ""
    for arg in args {
        outString += "arg=\(arg.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)&"
    }
    return outString
}

