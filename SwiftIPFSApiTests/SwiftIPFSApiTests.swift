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

class SwiftIPFSApiTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
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
        do {
            let group = dispatch_group_create()
            dispatch_group_enter(group)
            
            let api = try IPFSApi(host: "127.0.0.1", port: 5001)

            
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
                dispatch_group_leave(group)
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        } catch {
            XCTFail()
        }
    }
    
    func testSwarmAddrs() {
        do {
            let group = dispatch_group_create()
            dispatch_group_enter(group)
            
            let api = try IPFSApi(host: "127.0.0.1", port: 5001)
    
            try api.swarm.addrs(){
                addrs in

                for (hash, addrList)  in addrs {
                    print("Hash:",hash)
                    print("     ",addrList)
                }
                dispatch_group_leave(group)
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        } catch {
            XCTFail()
        }
    }

    func testSwarmConnect() {
        do {
            let group = dispatch_group_create()
            dispatch_group_enter(group)
            
            let api = try IPFSApi(host: "127.0.0.1", port: 5001)
            
            let peerAddress = "/ip4/104.131.131.82/tcp/4001/ipfs/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ"
            
            try api.swarm.connect(peerAddress){
                result in
                
//                for (hash, addrList)  in addrs {
//                    print("Hash:",hash)
//                    print("     ",addrList)
//                }
                dispatch_group_leave(group)
            }
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        } catch {
            XCTFail()
        }
    }
    
    func testBaseCommands() {
        do {
            let api = try IPFSApi(host: "127.0.0.1", port: 5001)
            let group = dispatch_group_create()
            
            // Test ls
            dispatch_group_enter(group)
            var multihash = try fromB58String("QmXYxW6Wzbqv7qAmN1QwTEvfvUaGiTVricrppE5VEnh7V7")
            
            try api.ls(multihash) {
                result in
                print("Bingo")
                dispatch_group_leave(group)
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)

            /// Test cat
            dispatch_group_enter(group)
            multihash = try fromB58String("QmNtFyK7cUSDyw91BfLDxWSRucmskcPAHdDtnrP1fmndhb")
            
            try api.cat(multihash) {
                result in
                print(result)
                dispatch_group_leave(group)
            }
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
       
            
        } catch {
            print("TestBaseCommands error: ",error)
            XCTFail()
        }
    }

    func testAdd() {
        
        let group = dispatch_group_create()
        // Test add
        dispatch_group_enter(group)
        
        do {

            let api = try IPFSApi(host: "127.0.0.1", port: 5001)
            let filePaths = ["file:///Users/teo/tmp/rb2.patch", "file:///Users/teo/tmp/notred.png","file:///Users/teo/tmp/woot"]
        
        
            try api.add(filePaths) {
                result in
                for mt in result {
                    print("Name:",mt.name)
                    print("Hash:",mt.hash!.string())
                }
            }
            
            dispatch_group_leave(group)
            
        } catch  {
            XCTFail("testMisc error: \(error)")
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