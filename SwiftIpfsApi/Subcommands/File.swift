//
//  File.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash

public class File : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
    public func ls(path: Multihash, completionHandler: ([String : AnyObject]) -> Void) throws {
        try parent!.fetchDictionary("file/ls?arg=" + b58String(path), completionHandler: completionHandler)
    }
}