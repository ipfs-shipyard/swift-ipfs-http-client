//
//  Diag.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 
import Foundation

/** Generates diagnostic reports */
public class Diag : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    /** Generates a network diagnostics report */
    public func net(_ completionHandler: @escaping (Result<String, Error>) -> Void) {
        parent!.fetchBytes("diag/net?stream-channels=true") { result in
            let transformation = result.flatMap { bytes -> Result<String, Error> in
                return .success(String(bytes: bytes, encoding: .utf8)!)
            }
            completionHandler(transformation)
        }
    }
    
    /* Prints out system diagnostic information. */
    public func sys(_ completionHandler: @escaping (Result<String, Error>) -> Void) {
        parent!.fetchBytes("diag/sys?stream-channels=true") { result in
            let transformation = result.flatMap { bytes -> Result<String, Error> in
                return .success(String(bytes: bytes, encoding: .utf8)!)
            }
            completionHandler(transformation)
        }
    }
}
