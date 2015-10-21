//
//  SwiftIPFSApiTests.swift
//  SwiftIPFSApiTests
//
//  Created by Teo on 20/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//

import XCTest
@testable import SwiftIPFSApi
import SwiftMultiaddr

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
    
    func testSwarm() {
        do {
            let group = dispatch_group_create()
            dispatch_group_enter(group)
            
            let api = try IPFSApi(host: "127.0.0.1", port: 5001)

            
            try api.swarm.peers(){ (peers: [Multiaddr]) in
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
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
