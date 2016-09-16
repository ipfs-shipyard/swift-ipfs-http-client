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
	public func local(_ completionHandler: @escaping ([Multihash]) -> Void) throws {
		try parent!.fetchData("refs/local") {
			(data: Data) in
			
			let parsedJson = try dataToJsonType(data: data)
			var multiaddrs = [Multihash]()
			
			if let refs = parsedJson.array {
				for refObj in refs {

					if let refString = refObj.object?["Ref"]?.string {
						multiaddrs.append(try fromB58String(refString))
					}
				}
			}
			/// At this point we have the refs as json.
			completionHandler(multiaddrs)
		}
	}
	
}
