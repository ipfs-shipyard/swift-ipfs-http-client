//
//  File.swift
//  SwiftIpfsApi
//
//  Created by Teo on 10/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import SwiftMultihash

/** Provides a familar interface to filesystems represtented by IPFS objects that
    hides IPFS-implementation details like layout objects (e.g. fanout and chunking). */
public class File : ClientSubCommand {
    
    var parent: IpfsApiClient?
    
/** Retrieves the object named by <ipfs-or-ipns-path> and displays the contents.

    The JSON output contains size information.  For files, the child size is the
    total size of the file contents.  
    For directories, the child size is the IPFS link size. */
    public func ls(_ path: String, completionHandler: @escaping (JsonType) -> Void) throws {
        try parent!.fetchJson("file/ls?arg=" + path, completionHandler: completionHandler)
    }
}
