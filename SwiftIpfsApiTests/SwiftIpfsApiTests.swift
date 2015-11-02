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
    
    func testRefsLocal() {
        
        let refsLocal = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.refs.local() {
                (localRefs: [Multihash]) in
                
                for mh in localRefs {
                    print(b58String(mh))
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(refsLocal)
    }
    
    func testPin() {
        
        let pinAdd = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("Qmb4b83vuYMmMYqj5XaucmEuNAcwNBATvPL6CNuQosjr91")
            
            try api.pin.add(multihash) {
                (pinnedHashes: [Multihash]) in
                
                for mh in pinnedHashes {
                    print(b58String(mh))
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(pinAdd)
        
        
        let pinLs = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.pin.ls() {
                (pinned: [Multihash : AnyObject]) in
                
                for (k,v) in pinned {
                    print("Hash:",b58String(k))
                    if let sd = v as? [String : AnyObject] {
                        print("Type:", sd["Type"] as! String)
                        print("Count:", sd["Count"] as! Int)
                    }
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(pinLs)
        
        let pinRm = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("Qmb4b83vuYMmMYqj5XaucmEuNAcwNBATvPL6CNuQosjr91")
            
            try api.pin.rm(multihash) {
                (removed: [Multihash]) in
                
                for hash in removed {
                    print("Removed hash:",b58String(hash))
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(pinRm)
    }
    
    func testRepo() {
        let repoGc = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            /// First we do an ls of something we know isn't pinned locally so that
            /// the gc has something to collect.
            let tmpGroup = dispatch_group_create()
            
            dispatch_group_enter(tmpGroup)

            let multihash = try fromB58String("QmTtqKeVpgQ73KbeoaaomvLoYMP7XKemhTgPNjasWjfh9b")
            try api.ls(multihash){ _ in dispatch_group_leave(tmpGroup) }
            dispatch_group_wait(tmpGroup, DISPATCH_TIME_FOREVER)
            
            
            try api.repo.gc() {
                (removed: [[String : AnyObject]]) in
                
                for ref in removed {
                    print("removed: ",ref["Key"]!)
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(repoGc)
    }
    
    func testBlock() {
        
        let blockPut = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let rawData: [UInt8] = Array("hej verden".utf8)
            
            try api.block.put(rawData) {
                (result: MerkleNode) in
                
                XCTAssert(b58String(result.hash!) == "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
                print("ipfs.block.put test:")
//                for mt in result {
                    print("Name:", result.name)
                    print("Hash:", b58String(result.hash!))
//                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(blockPut)
        
        
        let blockGet = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
            
            try api.block.get(multihash) {
                (result: [UInt8]) in
                    let res = String(bytes: result, encoding: NSUTF8StringEncoding)
                    XCTAssert(res == "hej verden")
                    print(res)
                    dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(blockGet)
        
        
        let blockStat = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
            
            try api.block.stat(multihash) {
                (result: Dictionary) in
                
                let hash = result["Key"] as? String
                let size = result["Size"] as? Int

                if hash == nil || size == nil
                    || hash != "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw"
                    || size != 10 {
                    XCTFail()
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(blockStat)
    }
    
    func testObject() {
        
        let objectNew = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.object.new() {
                (result: MerkleNode) in
                print(b58String(result.hash!))
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(objectNew)
        
        let objectPut = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let data = [UInt8]("{ \"Data\" : \"Dauz\" }".utf8)
            try api.object.put(data) {
                (result: MerkleNode) in
                
                print(b58String(result.hash!))
                //XCTAssert(b58String(result.hash!) == "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(objectPut)
        
        let objectGet = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("QmR3azp3CCGEFGZxcbZW7sbqRFuotSptcpMuN6nwThJ8x2")
            
            try api.object.get(multihash) {
                (result: MerkleNode) in
                
                print(b58String(result.hash!))
                //XCTAssert(b58String(result.hash!) == "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
                dispatch_group_leave(dispatchGroup)

            }
        }
        
        tester(objectGet)
        
        
        let objectLinks = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("QmR3azp3CCGEFGZxcbZW7sbqRFuotSptcpMuN6nwThJ8x2")
            
            try api.object.links(multihash) {
                (result: MerkleNode) in
                
                print(b58String(result.hash!))
                /// There should be two links off the root:
                if let links = result.links where links.count == 2 {
                    let link1 = links[0]
                    let link2 = links[1]
                    XCTAssert(b58String(link1.hash!) == "QmWfzntFwgPf9T9brQ6P2PL1BMoH16jZvhanGYtZQfgyaD")
                    XCTAssert(b58String(link2.hash!) == "QmRJ8Gngb5PmvoYDNZLrY6KujKPa4HxtJEXNkb5ehKydg2")
                } else {
                    XCTFail()
                }
                dispatch_group_leave(dispatchGroup)
                
            }
        }
        
        tester(objectLinks)
        
    }
    
    func testObjectPatch() {
        let objectPatch = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)

            let hash = "QmUYttJXpMQYvQk5DcX2owRUuYJBJM6W7KQSUsycCCE2MZ" /// a file
            /// Create a new directory object to start off with.
            try api.object.new(.UnixFsDir) {
                (result: MerkleNode) in
                do {
                    /** This uses the directory object to create a new object patched
                        with the given args. */
                    try api.object.patch(result.hash!, cmd: IpfsObject.ObjectPatchCommand.AddLink, args: "foo", hash) {
                        (result: MerkleNode) in
                        
                        print("object patch ",b58String(result.hash!))
                        
                        do {
                            /// get the new object's links to check against.
                            try api.object.links(result.hash!) {
                                (result: MerkleNode) in
                                
                                /// Check that the object's link is the same as 
                                /// what we originally passed to the patch command.
                                if let links = result.links where links.count == 1,
                                    let linkHash = links[0].hash where b58String(linkHash) == hash {}
                                else { XCTFail() }
                            }
                        } catch {
                            print(error)
                        }
                        dispatch_group_leave(dispatchGroup)
                    }
                } catch {
                    print("error", error)
                }
            }
            
            
        }
        
        tester(objectPatch)
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

//                for (hash, addrList)  in addrs {
//                    print("Hash:",hash)
//                    print("     ",addrList)
//                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(swarmAddrs)
    }

    func testSwarmConnect() {
        let swarmConnect = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let peerAddress = "/ip4/192.168.5.18/tcp/4001/ipfs/QmQyb7g2mCVYzRNHaEkhVcWVKnjZjc2z7dWKn1SKxDgTC3"
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.swarm.connect(peerAddress){
                result in
                
                XCTAssert(result == "connect QmQyb7g2mCVYzRNHaEkhVcWVKnjZjc2z7dWKn1SKxDgTC3 success")
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
                /// do comparison with truth here.
                dispatch_group_leave(dispatchGroup)
            }

        }
            
        tester(lsTest)
            
            
        let catTest = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let multihash = try fromB58String("QmNtFyK7cUSDyw91BfLDxWSRucmskcPAHdDtnrP1fmndhb")
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.cat(multihash) {
                result in
                print("cat:",String(bytes: result, encoding: NSUTF8StringEncoding)!)
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(catTest)
    }

    func testdns() {
        let dns = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api       = try IpfsApi(addr: "/ip4/127.0.0.1/tcp/5001")
            let domain    = "ipfs.io"
            try api.dns(domain) {
                domainString in
                
                print("Domain: ",domainString)
//                if domainString != "/ipfs/QmcQBvKTP8R7p8DgLEtKuoeuz1BBbotGpmofEFBEYBfc97" {
//                    XCTFail("domain string mismatch.")
//                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(dns)
    }
    
    func testMount() {
        let mount = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(addr: "/ip4/127.0.0.1/tcp/5001")
            
            try api.mount() {
                result in
                print("Mount got", result)
                dispatch_group_leave(dispatchGroup)
            }
            
        }
        
        tester(mount)
    }
    
    func testResolveIpfs() {
        let resolve = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(addr: "/ip4/127.0.0.1/tcp/5001")
            let multihash = try fromB58String("QmSEYztFJmcY7dSKS7ZXybzKMhHq3LM5zVt4EfCPMsejp3")
            
            try api.resolve("ipfs", hash: multihash, recursive: false) {
                result in
                print("Resolve IPFS got", result)
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(resolve)
    }
    
    func testResolveIpns() {
        let resolve = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(addr: "/ip4/127.0.0.1/tcp/5001")
            let multihash = try fromB58String("QmWNwhBWa9sWPvbuS5XNaLp6Phh5vRN77BZRF5xPWG3FN1")
            
            
            try api.resolve("ipns", hash: multihash, recursive: false) {
                result in
                print("Resolve IPNS got", result)
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(resolve)
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
                    print("Name:", mt.name)
                    print("Hash:", b58String(mt.hash!))
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(add)
    }
    
    func testRefs() {
        let refs = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let multihash = try fromB58String("QmSEYztFJmcY7dSKS7ZXybzKMhHq3LM5zVt4EfCPMsejp3")
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.refs(multihash, recursive: false) {
                result in
                for mh in result {
                    print(b58String(mh))
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        tester(refs)
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