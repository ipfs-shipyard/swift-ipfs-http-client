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
                (pinned: [Multihash : JsonType]) in
                
                for (k,v) in pinned {
                    print("\(b58String(k)) \((v.object?["Type"]?.string)!)")
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
            
            /** First we do an ls of something we know isn't pinned locally.
                This causes it to be copied to the local node so that the gc has
                something to collect. */
            let tmpGroup = dispatch_group_create()
            
            dispatch_group_enter(tmpGroup)

            let multihash = try fromB58String("QmTtqKeVpgQ73KbeoaaomvLoYMP7XKemhTgPNjasWjfh9b")
            try api.ls(multihash){ _ in dispatch_group_leave(tmpGroup) }
            dispatch_group_wait(tmpGroup, DISPATCH_TIME_FOREVER)
            
            
            try api.repo.gc() {
                result in
                if let removed = result.array {
                    for ref in removed {
                        print("removed: ",(ref.object?["Key"]?.string)!)
                    }
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
                    dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(blockGet)
        
        
        let blockStat = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
            
            try api.block.stat(multihash) {
                result in
                
                let hash = result.object?["Key"]?.string
                let size = result.object?["Size"]?.number

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
                
                /// A new ipfs object always has the same hash so we can assert against it.
                XCTAssert(b58String(result.hash!) == "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n")
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(objectNew)
        
        let objectPut = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let data = [UInt8]("{ \"Data\" : \"Dauz\" }".utf8)
            
            try api.object.put(data) {
                (result: MerkleNode) in
                
                XCTAssert(b58String(result.hash!) == "QmUqvXbE4s9oTQNhBXm2hFapLq1pnuuxsMdxP9haTzivN6")
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(objectPut)
        
        let objectGet = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String("QmUqvXbE4s9oTQNhBXm2hFapLq1pnuuxsMdxP9haTzivN6")
            
            try api.object.get(multihash) {
                (result: MerkleNode) in
                
                XCTAssert(result.data! == Array("Dauz".utf8))
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
        
        let setData = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            /// Get the empty directory object to start off with.
            try api.object.new() {
                (result: MerkleNode) in

                let data = "This is a longer message."
                try api.object.patch(result.hash!, cmd: .SetData, args: data) {
                    result in
                    
                    print(b58String(result.hash!))
                    dispatch_group_leave(dispatchGroup)
                }
            }
        }
        
        tester(setData)

        let appendData = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            /// The previous hash that was returned from setData
            let previousMultihash = try fromB58String("QmQXys2Xv5xiNBR21F1NNwqWC5cgHDnndKX4c3yXwP4ywj")
            /// Get the empty directory object to start off with.
            
            let data = "Addition to the message."
            try api.object.patch(previousMultihash, cmd: .AppendData, args: data) {
                result in
                
                print(b58String(result.hash!))
                
                /// Now we request the data from the new Multihash to compare it.
                try api.object.data(result.hash!) {
                    result in
                    
                    let resultString = String(bytes: result, encoding: NSUTF8StringEncoding)
                    XCTAssert(resultString == "This is a longer message.Addition to the message.")
                    dispatch_group_leave(dispatchGroup)
                }
            }
        }
        
        tester(appendData)

        
        let objectPatch = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)

            let hash = "QmUYttJXpMQYvQk5DcX2owRUuYJBJM6W7KQSUsycCCE2MZ" /// a file
            let hash2 = "QmVtU7ths96fMgZ8YSZAbKghyieq7AjxNdcqyVzxTt3qVe" /// a directory
            
            /// Get the empty directory object to start off with.
            try api.object.new(.UnixFsDir) {
                (result: MerkleNode) in

                /** This uses the directory object to create a new object patched
                    with the object of the given hash. */
                try api.object.patch(result.hash!, cmd: IpfsObject.ObjectPatchCommand.AddLink, args: "foo", hash) {
                    (result: MerkleNode) in
                    
                    /// Get a new object from the previous object patched with the object of hash2
                    try api.object.patch(result.hash!, cmd: IpfsObject.ObjectPatchCommand.AddLink, args: "ars", hash2) {
                        (result: MerkleNode) in
                        
                        /// get the new object's links to check against.
                        try api.object.links(result.hash!) {
                            (result: MerkleNode) in
                            
                            /// Check that the object's link is the same as 
                            /// what we originally passed to the patch command.
                            if let links = result.links where links.count == 2,
                                let linkHash = links[1].hash where b58String(linkHash) == hash {}
                            else { XCTFail() }
                            
                            /// Now try to remove it and check that we only have one link.
                            try api.object.patch(result.hash!, cmd: .RmLink, args: "foo") {
                                (result: MerkleNode) in
                                
                                /// get the new object's links to check against.
                                try api.object.links(result.hash!) {
                                    (result: MerkleNode) in

                                    if let links = result.links where links.count == 1,
                                        let linkHash = links[0].hash where b58String(linkHash) == hash2 {}
                                    else { XCTFail() }

                                    dispatch_group_leave(dispatchGroup)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        tester(objectPatch)
    }
    
    
    func testName() {
    
        let idHash = "QmTKWgmTLaosngT7txpZEVtwdxvJsX9pwKhmgMSbxwY7sN"
        let publishedPath = "/ipfs/" + idHash
        
        let publish = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let multihash = try fromB58String(idHash)
            try api.name.publish(hash: multihash) {
                result in
                
                XCTAssert(  (result.object?["Name"]?.string)! == "QmWNwhBWa9sWPvbuS5XNaLp6Phh5vRN77BZRF5xPWG3FN1" &&
                            (result.object?["Value"]?.string)! == publishedPath)
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(publish)
        
        let resolve = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.name.resolve(){
                result in
                XCTAssert(result == publishedPath)
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(resolve)
    }
    
    func testDht() {
        
        do {
            /// Common
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let neighbour = "QmQyb7g2mCVYzRNHaEkhVcWVKnjZjc2z7dWKn1SKxDgTC3"
            let multihash = try fromB58String("QmUYttJXpMQYvQk5DcX2owRUuYJBJM6W7KQSUsycCCE2MZ")
            
            let findProvs = { (dispatchGroup: dispatch_group_t) throws -> Void in
                try api.dht.findProvs(multihash) {
                    result in
                    
                    var pass = false
                    repeat {
                        guard case .Array(let providers) = result else { break }
                        
                        for prov in providers {
                            
                            guard   case .Object(let obj) = prov,
                                    case .Array(let responses) = obj["Responses"]! else { continue }
                            
                            for response in responses {
                                
                                guard   case .Object(let ars) = response,
                                        case .String(let provHash) = ars["ID"]! else { continue }
                                
                                /// This node should definitely be in the dht.
                                if provHash == "QmWNwhBWa9sWPvbuS5XNaLp6Phh5vRN77BZRF5xPWG3FN1" { pass = true }
                            }
                        }
                    } while false
                    
                    XCTAssert(pass)
                    
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
//            tester(findProvs)
            
            
            let query = { (dispatchGroup: dispatch_group_t) throws -> Void in
                /// This nearest works for me but may need changing to something local to the tester.
                let nearest = try fromB58String(neighbour)
                try api.dht.query(nearest) {
                    result in
                    /// assert against some known return value
                    print(result)
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
//            tester(query)
            
            
            let findPeer = { (dispatchGroup: dispatch_group_t) throws -> Void in
                /// This peer works for me but may need changing to something local to the tester.
                let peer = try fromB58String(neighbour)
                try api.dht.findpeer(peer) {
                    result in
                    
                    XCTAssert(result.object?["Responses"]?.array?[0].object?["ID"]?.string == neighbour)
                    
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
            tester(findPeer)
            
//            let put = { (dispatchGroup: dispatch_group_t) throws -> Void in
//            }
//            tester(put)
//            let get = { (dispatchGroup: dispatch_group_t) throws -> Void in
//            }
//            tester(get)
            
        } catch {
            print("testDht error \(error)")
        }
    }
    
    func testBootstrap() {
        
        do {
            
            let trustedPeer = "/ip4/104.131.131.82/tcp/4001/ipfs/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ"
            let trustedPeer2 = "/ip4/104.236.176.52/tcp/4001/ipfs/QmSoLnSGccFuZQJzRadHn95W2CrSFmZuTdDWP8HXaHca9z"

            let tpMultiaddr = try newMultiaddr(trustedPeer)
            let tpMultiaddr2 = try newMultiaddr(trustedPeer2)
            
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
        
            let rm = { (dispatchGroup: dispatch_group_t) throws -> Void in
                
                let tPeers = [tpMultiaddr, tpMultiaddr2]
                
                try api.bootstrap.rm(tPeers) {
                    (peers: [Multiaddr]) in
                    
                    for peer in peers {
                        print(try peer.string())
                    }

                    if peers.count == 2 {
                        let t1 = try peers[0].string() == trustedPeer
                        let t2 = try peers[1].string() == trustedPeer2
                        XCTAssert(t1 && t2)
                    } else { XCTFail() }
                    
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
            tester(rm)
            
            let bootstrap = { (dispatchGroup: dispatch_group_t) throws -> Void in
                
                try api.bootstrap.list() {
                    (peers: [Multiaddr]) in
                    for peer in peers {
                       print(try peer.string())
                    }
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
            tester(bootstrap)
            
            let add = { (dispatchGroup: dispatch_group_t) throws -> Void in
                
                let tPeers = [tpMultiaddr, tpMultiaddr2]
                
                try api.bootstrap.add(tPeers) {
                    (peers: [Multiaddr]) in
                    
                    for peer in peers {
                        print(try peer.string())
                    }

                    if peers.count == 2 {
                        let t1 = try peers[0].string() == trustedPeer
                        let t2 = try peers[1].string() == trustedPeer2
                        XCTAssert(t1 && t2)
                    } else { XCTFail() }
                    
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
            tester(add)
        
        } catch {
            print("Bootstrap test error: \(error)")
        }
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
    
    
    func testDiag() {
        
        let net = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.diag.net() {
                result in
                print(result)
                /// do comparison with truth here.
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(net)
        
        let sys = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.diag.sys() {
                result in
                print(result)
                /// do comparison with truth here.
                dispatch_group_leave(dispatchGroup)
            }
        }
        tester(sys)
    }
    
    func testConfig() {
        let show = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.config.show() {
                result in
                print(result)
                /// do comparison with truth here. Currently by visual inspection :/
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(show)
        
        let set = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.config.set("Teo", value: "42") {
                result in
                
                try api.config.get("Teo") {
                    result in
                    /// do comparison with truth here.
                    if case .String(let strResult) = result where strResult == "42" { } else {
                        XCTFail()
                    }
                    dispatch_group_leave(dispatchGroup)
                }
            }
        }
    
        tester(set)
        
   
        let get = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.config.get("Datastore.Type") {
                result in
                /// do comparison with truth here.
                if case .String(let strResult) = result where strResult == "leveldb" { } else {
                    XCTFail()
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(get)

    }
    
    
    func testBaseCommands() {
        
        /// For this test assert that the resulting links' name is Mel.html and MelKaye.png
        let lsTest = { (dispatchGroup: dispatch_group_t) throws -> Void in

            let multihash = try fromB58String("QmXsnbVWHNnLk3QGfzGCMy1J9GReWN7crPvY1DKmFdyypK")
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.ls(multihash) {
                results in
                
                var pass = false
                let node = results[0]
                if let links = node.links where
                        links.count == 2 &&
                        links[0].name! == "Mel.html" &&
                        links[1].name! == "MelKaye.png" {
                    pass = true
                }
                
                XCTAssert(pass)
                
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

    func testPing() {
        
        let ping = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.ping("QmQyb7g2mCVYzRNHaEkhVcWVKnjZjc2z7dWKn1SKxDgTC3") {
               result in
                
                if let pings = result.array {
                    for ping in pings {
                        print(ping.object?["Text"] ?? "-")
                        print(ping.object?["Time"] ?? "-")
                        print(ping.object?["Success"] ?? "-")
                    }
                }

                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(ping)
    }
    
    func testIds() {
        
        do {
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let idString = "QmWNwhBWa9sWPvbuS5XNaLp6Phh5vRN77BZRF5xPWG3FN1"
            
            let id = { (dispatchGroup: dispatch_group_t) throws -> Void in
                try api.id(idString) {
                    result in
                    
                    XCTAssert(result.object?["ID"]?.string == idString)
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
            tester(id)
            
            let idDefault = { (dispatchGroup: dispatch_group_t) throws -> Void in
                try api.id() {
                    result in
                    
                    XCTAssert(result.object?["ID"]?.string == idString)
                    dispatch_group_leave(dispatchGroup)
                }
            }
            
            tester(idDefault)
            
        } catch {
            print("testIds error:\(error)")
        }
    }
    
    
    func testVersion() {
        let version = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.version() {
                version in
                print(version)
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(version)
        
    }
    
    func testCommands() {
        let commands = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.commands(true) {
                result in
               
                if let commands = result.object {
                    for (k,v) in commands {
                        print("k: ",k)
                        print("v: ",v)
                    }
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(commands)
        
    }
    
    func testStats() {
        let stats = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            try api.stats.bw() {
                stats in
                
                for (k,v) in stats {
                    print("k: ",k)
                    print("v: ",v)
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        tester(stats)
        
    }
    
    func testLog() {
        let log = { (dispatchGroup: dispatch_group_t) throws -> Void in
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            let updateHandler = { (data: NSData) -> Bool in
                print("Got an update. Closing.")
                return false
            }
            
            try api.log(updateHandler) {
                log in
                
                for entry in log {
                    print(entry)
                }
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        //tester(log)
        
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
                XCTAssert(  result.object?["IPFS"]?.string == "/ipfs" &&
                            result.object?["IPNS"]?.string == "/ipns")
                dispatch_group_leave(dispatchGroup)
            }
            
        }
        
        tester(mount)
    }
    
    func testResolveIpfs() {
        let resolve = { (dispatchGroup: dispatch_group_t) throws -> Void in
            
            let api = try IpfsApi(addr: "/ip4/127.0.0.1/tcp/5001")
            let multihash = try fromB58String("QmXsnbVWHNnLk3QGfzGCMy1J9GReWN7crPvY1DKmFdyypK")
            
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
                
                XCTAssert(result.object?["Path"]?.string == "/ipfs/QmTKWgmTLaosngT7txpZEVtwdxvJsX9pwKhmgMSbxwY7sN")
                
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
            let multihash = try fromB58String("QmXsnbVWHNnLk3QGfzGCMy1J9GReWN7crPvY1DKmFdyypK")
            let api = try IpfsApi(host: "127.0.0.1", port: 5001)
            
            try api.refs(multihash, recursive: false) {
                result in
                
                XCTAssert(  result.count == 2 &&
                            b58String(result[0]) == "QmZX6Wrte3EqkUCwLHqBbuDhmH5yqPurNNTxKQc4NFfDxT" &&
                            b58String(result[1]) == "QmaLB324wDRKEJbGGr8FWg3qWnpTxdc2oEKDT62qhe8tMR" )
//                for mh in result {
//                    print(b58String(mh))
//                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        tester(refs)
    }
    
    
    
    /// Utility functions
    
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