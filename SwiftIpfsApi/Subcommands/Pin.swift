//
//  Pin.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash

/** Pinning an object will ensure a local copy is not garbage collected. */
public class Pin : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func add(_ hash: Multihash, completionHandler: @escaping (Result<[Multihash], Error>) -> Void) {
        parent!.fetchJson("pin/add?stream-channels=true&arg=\(b58String(hash))") { result in
            let transformation = result.flatMap { json -> Result<[Multihash], Error> in
                do {
                    guard let objects = json.object?["Pins"]?.array else {
                        throw IpfsApiError.pinError("Pin.add error: No Pinned objects in JSON data.")
                    }

                    let compactObjects: [Multihash] = try objects.compactMap {
                        guard let safeString = $0.string else {
                            return nil
                        }

                        return try fromB58String(safeString)
                    }

                    return .success(compactObjects)
                } catch {
                    return .failure(error)
                }
            }
            completionHandler(transformation)
        }
    }
    
    /** List objects pinned to local storage */
    public func ls(_ completionHandler: @escaping (Result<[Multihash: JsonType], Error>) -> Void) {
        
        // The default is .Recursive
        ls(.recursive) { result in
            let transformation = result.flatMap { json -> Result<[Multihash: JsonType], Error> in
                do {
                    var multihashes = [Multihash : JsonType]()
                    if let hashes = json.object {
                        for (k,v) in hashes {
                            multihashes[try fromB58String(k)] = v
                        }
                    }
                    return .success(multihashes)
                } catch {
                    return .failure(error)
                }
            }
            completionHandler(transformation)
        }
    }
    
    public func ls(_ pinType: PinType, completionHandler: @escaping (Result<JsonType, Error>) -> Void) {
        parent!.fetchJson("pin/ls?stream-channels=true&t=" + pinType.rawValue) { result in
            let transformation = result.flatMap { data -> Result<JsonType, Error> in
                guard let objects = data.object?[IpfsCmdString.Keys.rawValue] else {
                    return .failure(IpfsApiError.pinError("Pin.ls error: No Keys Dictionary in JSON data."))
                }

                return .success(objects)
            }
            completionHandler(transformation)
        }
    }
    
    public func rm(_ hash: Multihash, completionHandler: @escaping (Result<[Multihash], Error>) -> Void) {
        self.rm(hash, recursive: true, completionHandler: completionHandler)
    }
    
    public func rm(_ hash: Multihash, recursive: Bool, completionHandler: @escaping (Result<[Multihash], Error>) -> Void) {
        parent!.fetchJson("pin/rm?stream-channels=true&r=\(recursive)&arg=\(b58String(hash))") { result in

            let transformation = result.flatMap { data -> Result<[Multihash], Error> in
                do {
                    guard let objects = data.object?["Pins"]?.array else {
                        throw IpfsApiError.pinError("Pin.rm error: No Pinned objects in JSON data.")
                    }

                    let compactObjects: [Multihash] = try objects.compactMap {
                        guard let safeString = $0.string else {
                            return nil
                        }

                        return try fromB58String(safeString)
                    }

                    return .success(compactObjects)
                } catch {
                    return .failure(error)
                }
            }
            completionHandler(transformation)
        }
    }
    
}
