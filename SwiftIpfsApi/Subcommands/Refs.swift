//
//  Refs.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash

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