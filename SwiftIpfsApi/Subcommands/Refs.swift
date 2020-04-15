//
//  Refs.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 
import Foundation
import SwiftMultihash

/** Lists links (references) from an object */
public class Refs : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    struct Reference : Codable {
        let Ref: String
        let Err: String
    }
    
    public func local(_ completionHandler: @escaping (Result<[Multihash], Error>) -> Void) {
        parent!.fetchData("refs/local") { result in
            let transformation = result.flatMap { data -> Result<[Multihash], Error> in
                do {
                    let fixedJsonData = fixStreamJson(data)
                    let decoder = JSONDecoder()
                    let refs = try decoder.decode([Reference].self, from: fixedJsonData)
                    /** The resulting string is a bunch of newline separated strings so:
                     1) Split the string up by the separator into a subsequence,
                     2) Map each resulting subsequence into a string,
                     3) Map each string into a Multihash with fromB58String. */
                    let c = try refs.map { reference -> Multihash in
                        print("reference is \(reference.Ref)")
                        print("error is \(reference.Err)")
                        return try fromB58String(reference.Ref)
                    }
                    return .success(c)
                } catch {
                    return .failure(error)
                }
            }
            completionHandler(transformation)
        }
    }
}
