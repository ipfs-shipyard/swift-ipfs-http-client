//
//  Dht.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash
import SwiftMultiaddr
import Foundation

public class Dht : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    /** FindProviders will return a list of peers who are able to provide the value requested. */
    public func findProvs(_ hash: Multihash, numProviders: Int = 20, completionHandler: @escaping (JsonType) -> Void) throws {
        // Two test closures to be passed to the fetchStreamJson as parameters.
        let comp = { (result: AnyObject) -> Void in
            print("Job done")
        }
        
        let update : ((Data, URLSessionDataTask) -> Bool) = { (data: Data, task: URLSessionDataTask) -> Bool in

            func getHash(from obj: [String : JsonType], forResponse type: Int) -> [String]? {
                
                if obj["Type"]?.number?.intValue == type {
                    if let responses = obj["Responses"]?.array {
                        // only keep the responses that contain an ID.
                        return responses.compactMap { $0.object?["ID"]?.string }
                    }
                }
                return nil
            }
            

            print("updates")
            let fixed = fixStreamJson(data)
            let json = try? JSONSerialization.jsonObject(with: fixed, options: JSONSerialization.ReadingOptions.allowFragments)
            let parsedJ = JsonType.parse(json as AnyObject)
            
            var providers = [JsonType]()
            // A valid response can either be an array of objects or an object.
            switch parsedJ {
            case JsonType.array(let array):
                providers += array.filter { $0.object?["Type"]?.number == 4 }
            case JsonType.object(let obj):
                if obj["Type"]?.number == 4 {
                    providers.append(parsedJ)
                }
            default:
                break
            }
            
            if providers.count >= numProviders {
                print("We found these providers \(providers)")
                let provs = JsonType.parse(providers as AnyObject)
                completionHandler(provs)
                
            }

            return true
        }
        
        try parent!.fetchStreamJson("dht/findprovs?arg=\(b58String(hash))&num-providers=\(numProviders)", updateHandler: update, completionHandler: comp)
    }
   
    /** Run a 'findClosestPeers' query through the DHT */
    public func query(_ hash: Multihash, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("dht/query?arg=" + b58String(hash) , completionHandler: completionHandler)
    }
    
    /** Run a 'FindPeer' query through the DHT */
    public func findpeer(_ hash: Multihash, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("dht/findpeer?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    /** Will return the value stored in the dht at the given key */
    public func get(_ hash: Multihash, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("dht/get?arg=" + b58String(hash), completionHandler: completionHandler)
    }
    
    /** Will store the given key value pair in the dht. */
    public func put(_ key: String, value: String, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("dht/put?arg=\(key)&arg=\(value)", completionHandler: completionHandler)
    }
}
