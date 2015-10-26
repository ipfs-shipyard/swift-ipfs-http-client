//
//  SwiftIpfsApiTests.swift
//  SwiftIpfsApiTests
//
//  Created by Matteo Sartori on 20/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details.

import XCTest
@testable import SwiftIpfsApi
import SwiftMultiaddr
import SwiftMultihash

class SwiftIpfsApiTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBoundary() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let soRandom = Multipart.createBoundary()
        print(soRandom.characters.count)
    }
    
    func testSwarmPeers() {
        let swarmPeers = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.swarm.peers(){
                (peers: [Multiaddr]) in
                
                do {
                    for peer in peers {
                        print("Multiaddr: ", try peer.string())
                    }
                } catch {
                    print("testSwarm error",error)
                    XCTFail()
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(swarmPeers)
    }
    
    func testSwarmAddrs() {
        let swarmAddrs = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.swarm.addrs(){
                addrs in

                for (hash, addrList)  in addrs {
                    print("Hash:",hash)
                    print("     ",addrList)
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(swarmAddrs)
    }

    func testSwarmConnect() {
        let swarmConnect = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let peerAddress = "/ip4/104.131.131.82/tcp/4001/ipfs/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ"
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.swarm.connect(peerAddress){
                result in
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(swarmConnect)
    }
    
    func testBaseCommands() {
        
        let lsTest = { (dispatchGroup: dispatch_group_t) throws -> Void in

            let multihash = try fromB58String("QmXYxW6Wzbqv7qAmN1QwTEvfvUaGiTVricrppE5VEnh7V7")
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.ls(multihash) {
                result in
                print("Bingo")
                dispatch_group_leave(dispatchGroup)
            }

        }
            
        tester(lsTest)
            
            
        let catTest = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let multihash = try fromB58String("QmNtFyK7cUSDyw91BfLDxWSRucmskcPAHdDtnrP1fmndhb")
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.cat(multihash) {
                result in
                print(result)
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(catTest)
    }

    
    func testAdd() {
        
        let add = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let filePaths = [   "file:///Users/teo/tmp/rb2.patch",
                                "file:///Users/teo/tmp/notred.png",
                                "file:///Users/teo/tmp/woot"]
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.add(filePaths) {
                result in
                for mt in result {
                    print("Name:",mt.name)
                    print("Hash:",mt.hash!.string())
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(add)
    }
    
    
    func tester(test: (dispatchGroup: dispatch_group_t) throws -> Void) {
        
        let group = dispatch_group_create()
        
        dispatch_group_enter(group)
        
        do {
            /// Perform the test.
            try test(dispatchGroup: group)
            
        } catch  {
            XCTFail("tester error: \(error)")
        }
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
/** Template for test
do {
    let group = dispatch_group_create()
    dispatch_group_enter(group)

    let api = try IPFSApi(host: "127.0.0.1", port: 5001)
    let multihash = try fromB58String("QmWPmgXnRn81QMPpfRGQ9ttQXsgfe2YwQxJ9PEB99E6KJh")

    try api.??(??) {
        result in
        print("Bingo")

        dispatch_group_leave(group)
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
} catch {
    print("TestBaseCommands error: ",error)
    XCTFail()
}
*/