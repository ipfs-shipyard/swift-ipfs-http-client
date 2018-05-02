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

//    var hostString      = "ipfs-thing.localhost"//192.168.5.9" //127.0.0.1" //"192.168.5.8"
    var hostString      = "127.0.0.1"
    let hostPort        = 5001
    
    /// Your own IPNS node hash
    let nodeIdString    = "QmWNwhBWa9sWPvbuS5XNaLp6Phh5vRN77BZRF5xPWG3FN1"
//    let nodeIdString    = "QmRzsihDMWML1dNPa51qwD2dacvZPfTrqsQt4pi1DWGJFP"
    
    /// Another known neighbouring hash
//    let altNodeIdString = "QmWqjusr86LThkYgjAbNMa8gJ55wzVufkcv5E2TFfzYZXu"
    let altNodeIdString = "QmSoLnSGccFuZQJzRadHn95W2CrSFmZuTdDWP8HXaHca9z"

    let peerIPAddr = "/ip4/10.12.0.8/tcp/4001"
    
    let currentIpfsVersion = "0.4.14"
    
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
        print(soRandom.count)
    }
    
    // FIX: Fails due to issue in Multihash not recognizing new non Qm style hashes.
    func testRefsLocal() {
        
        let expectation = XCTestExpectation(description: "testRefsLocal")
        
        do {

        
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)

            try api.refs.local() { (localRefs: [Multihash]) in
                
                for mh in localRefs {
                    print(b58String(mh))
                }
                
                expectation.fulfill()
            }
        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 50.0)
    }
    
    // FIX: Fails due to issue in Multihash not recognizing new non Qm style hashes.
    func testPin() {
        
        let pinAddExpectation = XCTestExpectation(description: "testPinAdd")
        let pinLsExpectation = XCTestExpectation(description: "testPinLs")
        let pinRmExpectation = XCTestExpectation(description: "testPinRm")
        
        do {
            
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            let multihash = try fromB58String("Qmb4b83vuYMmMYqj5XaucmEuNAcwNBATvPL6CNuQosjr91")
            
            try api.pin.add(multihash) {
                (pinnedHashes: [Multihash]) in
                
                for mh in pinnedHashes {
                    print(b58String(mh))
                }
                
                pinAddExpectation.fulfill()
                
                // Pin Ls. Visual inspection for now. Change to check for added pin.
                try? api.pin.ls() { (pinned: [Multihash : JsonType]) in
    
                    for (k,v) in pinned {
                        print("\(b58String(k)) \((v.object?["Type"]?.string)!)")
                    }
                    pinLsExpectation.fulfill()

                    // Pin Rm. Remove previously pinned hash.
                    try? api.pin.rm(multihash) { (removed: [Multihash]) in
        
                        for hash in removed {
                            print("Removed hash:",b58String(hash))
                        }
                       
                        pinRmExpectation.fulfill()
                    }
                }
            }
        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [pinAddExpectation, pinLsExpectation, pinRmExpectation], timeout: 50.0)
    }
    
    func testRepo() {

        let lsExpectation = XCTestExpectation(description: "ls")
        let repoGcExpectation = XCTestExpectation(description: "testRepoGc")
        
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            /** First we do an ls of something we know isn't pinned locally.
                This causes it to be copied to the local node so that the gc has
                something to collect. */

            let multihash = try fromB58String("QmTtqKeVpgQ73KbeoaaomvLoYMP7XKemhTgPNjasWjfh9b")
        
            try api.ls(multihash) { _ in
                
                lsExpectation.fulfill()
                
                try? api.repo.gc() { result in
                    
                    if let removed = result.array {
                        for ref in removed {
                            print("removed: ",(ref.object?["Key"]?.string)!)
                        }
                    }
                    repoGcExpectation.fulfill()
                }
            }
        } catch {
            XCTFail()
        }
        
        wait(for: [lsExpectation, repoGcExpectation], timeout: 300.0)
    }
    
    func testBlock() {
        
        let blockPutExpectation = XCTestExpectation(description: "testBlockPut")
        let blockGetExpectation = XCTestExpectation(description: "testBlockGet")
        let blockStatExpectation = XCTestExpectation(description: "testBlockStat")
        
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            let rawData: [UInt8] = Array("hej verden".utf8)
            
            try api.block.put(rawData) { (result: MerkleNode) in
                
                XCTAssert(b58String(result.hash!) == "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
//                print("ipfs.block.put test:")
//                print("Name: ", result.name ?? "No name!")
//                print("Hash: ", b58String(result.hash!))

                blockPutExpectation.fulfill()
            }
            
            // Block Get.
            var multihash = try fromB58String("QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
            
            try api.block.get(multihash) { (result: [UInt8]) in
                let res = String(bytes: result, encoding: String.Encoding.utf8)
                XCTAssert(res == "hej verden")
                
                blockGetExpectation.fulfill()
            }

            // Block Stat.
            multihash = try fromB58String("QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
            
            try api.block.stat(multihash) { result in
                
                let hash = result.object?["Key"]?.string
                let size = result.object?["Size"]?.number
                
                if hash == nil || size == nil
                    || hash != "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw"
                    || size != 10 {
                    XCTFail()
                }
                blockStatExpectation.fulfill()
            }

        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [blockPutExpectation, blockGetExpectation, blockStatExpectation], timeout: 50.0)
    }
    
    func testObject() {
        
        let objNewExpectation = XCTestExpectation(description: "testObjectNew")
        let objPutExpectation = XCTestExpectation(description: "testObjectPut")
        let objGetExpectation = XCTestExpectation(description: "testObjectGet")
        let objLinksExpectation = XCTestExpectation(description: "testObjectLinks")
        
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.object.new() {
                (result: MerkleNode) in
                
                /// A new ipfs object always has the same hash so we can assert against it.
                XCTAssert(b58String(result.hash!) == "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n")
                objNewExpectation.fulfill()
            }

            
            // Test Object Put
            let data = [UInt8]("{ \"Data\" : \"Dauz\" }".utf8)

            try api.object.put(data) { (result: MerkleNode) in

                XCTAssert(b58String(result.hash!) == "QmUqvXbE4s9oTQNhBXm2hFapLq1pnuuxsMdxP9haTzivN6")
                objPutExpectation.fulfill()
            }

            // Test Object Get
            var multihash = try fromB58String("QmUqvXbE4s9oTQNhBXm2hFapLq1pnuuxsMdxP9haTzivN6")

            try api.object.get(multihash) { (result: MerkleNode) in

                XCTAssert(result.data! == Array("Dauz".utf8))
                objGetExpectation.fulfill()
            }

            // Test Object Links
            multihash = try fromB58String("QmR3azp3CCGEFGZxcbZW7sbqRFuotSptcpMuN6nwThJ8x2")

            try api.object.links(multihash) { (result: MerkleNode) in

                print(b58String(result.hash!))
                /// There should be two links off the root:
                if let links = result.links, links.count == 2 {
                    let link1 = links[0]
                    let link2 = links[1]
                    XCTAssert(b58String(link1.hash!) == "QmWfzntFwgPf9T9brQ6P2PL1BMoH16jZvhanGYtZQfgyaD")
                    XCTAssert(b58String(link2.hash!) == "QmRJ8Gngb5PmvoYDNZLrY6KujKPa4HxtJEXNkb5ehKydg2")
                } else {
                    XCTFail()
                }
                objLinksExpectation.fulfill()

            }

        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [objNewExpectation, objPutExpectation, objGetExpectation, objLinksExpectation], timeout: 50.0)
    }

    func testObjectPatch() {
        
        let objNewExpectation = XCTestExpectation(description: "testObjectNew")
        let objPatchExpectation = XCTestExpectation(description: "testObjectPatch")
        let objLinksExpectation = XCTestExpectation(description: "testObjectLinks")
        do {
        
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            /// Get the empty directory object to start off with.
            try api.object.new() {
                (result: MerkleNode) in

                let data = "This is a longer message."
                try api.object.patch(result.hash!, cmd: .SetData, args: data) {
                    result in
                    
                    print(b58String(result.hash!))
                    
                    objNewExpectation.fulfill()
                    
                    /// The previous hash that was returned from setData
                    let previousMultihash = try fromB58String("QmQXys2Xv5xiNBR21F1NNwqWC5cgHDnndKX4c3yXwP4ywj")
                    /// Get the empty directory object to start off with.
                    
                    let data = " Addition to the message."
                    try api.object.patch(previousMultihash, cmd: .AppendData, args: data) {
                        result in
                        
                        print(b58String(result.hash!))
                        
                        /// Now we request the data from the new Multihash to compare it.
                        try api.object.data(result.hash!) {
                            result in
                            
                            let resultString = String(bytes: result, encoding: String.Encoding.utf8)
                            XCTAssert(resultString == "This is a longer message. Addition to the message.")
                            
                            objPatchExpectation.fulfill()
                            
                            let hash = "QmUYttJXpMQYvQk5DcX2owRUuYJBJM6W7KQSUsycCCE2MZ" /// a file
                            let hash2 = "QmVtU7ths96fMgZ8YSZAbKghyieq7AjxNdcqyVzxTt3qVe" /// a directory
                            
                            /// Get the empty directory object to start off with.
                            try? api.object.new(.UnixFsDir) {
                                (result: MerkleNode) in
                                
                                /** This uses the directory object to create a new object patched
                                 with the object of the given hash. */
                                try? api.object.patch(result.hash!, cmd: IpfsObject.ObjectPatchCommand.AddLink, args: "foo", hash) {
                                    (result: MerkleNode) in
                                    
                                    /// Get a new object from the previous object patched with the object of hash2
                                    try? api.object.patch(result.hash!, cmd: IpfsObject.ObjectPatchCommand.AddLink, args: "ars", hash2) {
                                        (result: MerkleNode) in
                                        
                                        /// get the new object's links to check against.
                                        try? api.object.links(result.hash!) {
                                            (result: MerkleNode) in
                                            
                                            /// Check that the object's link is the same as
                                            /// what we originally passed to the patch command.
                                            if let links = result.links, links.count == 2,
                                                let linkHash = links[1].hash, b58String(linkHash) == hash {}
                                            else { XCTFail() }
                                            
                                            /// Now try to remove it and check that we only have one link.
                                            try? api.object.patch(result.hash!, cmd: .RmLink, args: "foo") {
                                                (result: MerkleNode) in
                                                
                                                /// get the new object's links to check against.
                                                try? api.object.links(result.hash!) {
                                                    (result: MerkleNode) in
                                                    
                                                    if let links = result.links, links.count == 1,
                                                        let linkHash = links[0].hash, b58String(linkHash) == hash2 {}
                                                    else { XCTFail() }
                                                    
                                                    objLinksExpectation.fulfill()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                        }
                    }

                }
            }
        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [objNewExpectation, objPatchExpectation, objLinksExpectation], timeout: 50.0)
    }
    
    
    func testNameResolve() {
        
        let nameResolveExpectation = XCTestExpectation(description: "testNameResolve")
        let namePublishExpectation = XCTestExpectation(description: "testNamePublish")
        let nameResolve2Expectation = XCTestExpectation(description: "testNameResolve2")
        
        do {

            var idHash: String = ""
            /// Start test by storing the existing hash so we can restore it after testing.

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.name.resolve() { result in
                
                idHash = result.replacingOccurrences(of: "/ipfs/", with: "")
                
                nameResolveExpectation.fulfill()
                
                let publishedPath = "/ipfs/" + idHash
                do {
                    //let multihash = try fromB58String(idHash)
                    
//                    try api.name.publish(hash: multihash) { result in
                    try api.name.publish(ipfsPath: publishedPath) { result in
                        
                        XCTAssert(  (result.object?["Name"]?.string)! == self.nodeIdString &&
                            (result.object?["Value"]?.string)! == publishedPath)
                        
                        namePublishExpectation.fulfill()
                        
                        try? api.name.resolve(){ result in
                            XCTAssert(result == publishedPath)
                            nameResolve2Expectation.fulfill()
                        }
                    }
                } catch {
                    XCTFail()
                }

            }
        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [nameResolveExpectation, namePublishExpectation, nameResolve2Expectation], timeout: 250.0)
    }
    
    
    // Fails on timeout because the api doesn't return – it keeps looking.
    func testDhtFindProvs() {

        let expectation = XCTestExpectation(description: "testFindProvs")
        do {
            /// Common
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)

            let multihash = try fromB58String("QmUFtMrBHqdjTtbebsL6YGebvjShh3Jud1insUv12fEVdA")
            
            try api.dht.findProvs(multihash, numProviders: 1) {
                result in
                
                // For each (if any) element in the result array we filter out
                // any objects with an ID that matches the localhost node's id hash.
                let matchingProviders = result.array?.compactMap { $0.object?["Responses"]?.array?.filter { $0.object?["ID"]?.string == self.nodeIdString }}
                
                let count = matchingProviders?.count ?? 0
                XCTAssert(count > 0)
                
                expectation.fulfill()
            }
        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // This test fails on timeout because the api doesn't actually end and thus doesn't return. Fix somehow.
    func testDhtQuery() {
        
        let expectation = XCTestExpectation(description: "testDhtQuery")
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            let neighbour = self.altNodeIdString
            /// This nearest works for me but may need changing to something local to the tester.
            let nearest = try fromB58String(neighbour)
            try api.dht.query(nearest) {
                result in
                /// assert against some known return value
                print(result)
                expectation.fulfill()
            }
        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testDhtFindPeer() {
        
        let expectation = XCTestExpectation(description: "testDhtFindPeer")
        do {
            
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            let neighbour = self.altNodeIdString
            /// This peer works for me but may need changing to something local to the tester.
            let peer = try fromB58String(neighbour)
            
            /// At the moment the findpeer wraps the stream json in an array
            try api.dht.findpeer(peer) {
                result in
                
                var pass = false
                
                if let resArray = result.object?["Responses"]?.array {
                    for res in resArray {
                        if res.object?["ID"]?.string == neighbour {
                            pass = true
                        }
                    }
                }
                XCTAssert(pass)
                
                expectation.fulfill()
            }
            
        } catch {
            XCTFail("test failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    /// If this fails check from the command line that the ipns path actually resolves
    /// to the checkHash before thinking this is actually broken. Ipns links do change.
    func testFileLs() {
                
        let ipnsExpectation = XCTestExpectation(description: "testIpnsLs")
        let ipfsExpectation = XCTestExpectation(description: "testIpfsLs")
        
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            /// basedir hash
            var path = "/ipns/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ"
            
            /// lvl2file hash
            let checkIpnsHash = "QmV1imZz8VRiYFw7ZSSUtTFtcaYA5iJXURkxLhEJssBXvy"

            try api.file.ls(path) { result in
                
                if let foundHash = result.object?["Objects"]?.object?[checkIpnsHash]?.object?["Hash"]?.string {
                    
                    XCTAssert(foundHash == checkIpnsHash)
                } else { XCTFail() }
                
                ipnsExpectation.fulfill()
            }
            
            let objHash = "QmQuQzFkULYToUBrMtyHg2tjvcd93N4kNHPCxfcFthB2kU"
            let checkIpfsHash = "QmQHAVCpAQxU21bK8VxeWisn19RRC4bLNFV4DiyXDDyLXM"
            path = "/ipfs/" + objHash
            
            try api.file.ls(path) { result in
                
                XCTAssert(result.object?["Objects"]?.object?[objHash]?.object?["Links"]?.array?[0].object?["Hash"]?.string == checkIpfsHash)
                
                ipfsExpectation.fulfill()
            }
        } catch {
            XCTFail("testFileLs failed with error \(error)")
        }
        
        wait(for: [ipnsExpectation, ipfsExpectation], timeout: 35.0)
    }
    
    func testBootstrap() {
        
        let trustedPeer = "/ip4/104.131.131.82/tcp/4001/ipfs/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ"
        let trustedPeer2 = "/ip4/104.236.176.52/tcp/4001/ipfs/QmSoLnSGccFuZQJzRadHn95W2CrSFmZuTdDWP8HXaHca9z"
    
        let bootstrapRmExpectation = XCTestExpectation(description: "testBootstrapRm")
        let bootstrapListExpectation = XCTestExpectation(description: "testBootstrapList")
        let bootstrapAddExpectation = XCTestExpectation(description: "testBootstrapAdd")
        
        do {
            let tpMultiaddr = try newMultiaddr(trustedPeer)
            let tpMultiaddr2 = try newMultiaddr(trustedPeer2)
            
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)

            let tPeers = [tpMultiaddr, tpMultiaddr2]
            
            try api.bootstrap.list() { (peers: [Multiaddr]) in
                
                for peer in peers {
                    print(try peer.string())
                }
                bootstrapListExpectation.fulfill()
            }
            
            try api.bootstrap.add(tPeers) { (peers: [Multiaddr]) in
                
                for peer in peers {
                    print(try peer.string())
                }
                
                if peers.count == 2 {
                    let t1 = try peers[0].string() == trustedPeer
                    let t2 = try peers[1].string() == trustedPeer2
                    XCTAssert(t1 && t2)
                } else { XCTFail() }
                
                bootstrapAddExpectation.fulfill()
                
                try api.bootstrap.rm(tPeers) { (peers: [Multiaddr]) in
                    
                    for peer in peers {
                        print(try peer.string())
                    }
                    
                    let a = try peers[0].string() == trustedPeer
                    let b = try peers[1].string() == trustedPeer2
                    XCTAssert(peers.count == 2 && a && b)
                    
                    bootstrapRmExpectation.fulfill()
                }
            }

        } catch {
            XCTFail("testLog failed with error \(error)")
        }
        
        wait(for: [bootstrapRmExpectation, bootstrapListExpectation, bootstrapAddExpectation], timeout: 5.0)
    }
    
    func testSwarmPeers() {
        
        /// NB: This test will require the user to change the knownPeer to a known peer.
        let knownPeer = peerIPAddr+"/ipfs/"+self.altNodeIdString
        
        let expectation = XCTestExpectation(description: "testSwarmPeers")
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.swarm.peers(){ (peers: [Multiaddr]) in
                
                var pass = false
                for peer in peers {
                    pass = (try peer.string() == knownPeer)
                    if pass { break }
                }
                
                XCTAssert(pass)
                expectation.fulfill()
            }
        } catch {
            XCTFail("testSwarmPeers failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSwarmAddrs() {
        
        let expectation = XCTestExpectation(description: "testSwarmAddrs")
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.swarm.addrs(){ addrs in

                if let addr = addrs.object?[self.altNodeIdString]?.array?[0].string {
                    XCTAssert(addr == self.peerIPAddr)
                } else { XCTFail() }
                
                expectation.fulfill()
            }
        } catch {
            XCTFail("testSwarmAddrs failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }

    func testSwarmConnect() {
        
        let expectation = XCTestExpectation(description: "testSwarmConnect")
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            /// NB: This test will require the user to change the peerAddress to a known peer.
            let peerAddress = self.peerIPAddr+"/ipfs/"+self.altNodeIdString
            let expectedMessage = "connect \(self.altNodeIdString) success"
            
            try api.swarm.connect(peerAddress){ result in
                
                if let msg = result.object?["Strings"]?.array?[0].string {
                    XCTAssert(msg == expectedMessage)
                } else { XCTFail() }
                
                // Not currently working as expected due to circuit relay implementation.
                // see https://discuss.ipfs.io/t/ipfs-swarm-disconnect-failure-conn-not-found/2553/6
                try api.swarm.disconnect(peerAddress) { result in
                    
                    if let msg = result.object?["Strings"]?.array?[0].string {
                        XCTAssert(msg == "dis" + expectedMessage)
                    } else { XCTFail() }
                    
                    expectation.fulfill()
                }
            }
        } catch {
            XCTFail("testSwarmConnect failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    
    func testDiag() {
        
        let expectation = XCTestExpectation(description: "testDiagSys")
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            try api.diag.sys() {
                result in
                print("diag sys result: \(result)")
                /// do comparison with truth here.
                expectation.fulfill()
            }

        } catch {
            XCTFail("testDiag failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConfig() {
        
        do {
            let configShowExpectation = XCTestExpectation(description: "testConfigShow")
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            try api.config.show() {
                result in
                print(result)
                /// do comparison with truth here. Currently by visual inspection :/
                configShowExpectation.fulfill()
            }

            let configSetExpectation = XCTestExpectation(description: "testConfigSet")
            let configSetGetExpectation = XCTestExpectation(description: "setGetExpectation")
            
            // Set a value in the config and read back the same to confirm.
            try api.config.set("Teo", value: "42") {
                result in
                
                configSetExpectation.fulfill()
                
                try api.config.get("Teo") {
                    result in
                    
                    if let strValue = result.string {
                        XCTAssertTrue(strValue == "42")
                    } else {  XCTFail() }
                    
                    configSetGetExpectation.fulfill()
                }
                
            }
            
            wait(for: [configShowExpectation, configSetExpectation, configSetGetExpectation], timeout: 25.0)

        } catch {
            XCTFail("testConfig failed with error \(error)")
        }
    }
    
    
    func testLs() {
        
        let expectation = XCTestExpectation(description: "testLs")
        do {
            let multihash = try fromB58String("QmPXME1oRtoT627YKaDPDQ3PwA8tdP9rWuAAweLzqSwAWT")
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.ls(multihash) {
                results in
                
                
                let node = results[0]
                if let links = node.links {
                    let pass = (links.count == 5 &&
                        links[0].name! == "contact" &&
                        links[1].name! == "help" &&
                        links[2].name! == "quick-start" &&
                        links[3].name! == "readme" &&
                        links[4].name! == "security-notes")
                    
                    XCTAssertTrue(pass)
                } else {
                    XCTFail("testLs no links found.")
                }
                
                expectation.fulfill()
            }
        } catch {
            XCTFail("testLs failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
        
    func testCat() {

        let expectation = XCTestExpectation(description: "testCat")
        do {

            let multihash = try fromB58String("QmYeQA5P2YuCKxZfSbjhiEGD3NAnwtdwLL6evFoVgX1ULQ")
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            try api.cat(multihash) {
                result in
                print("cat:",String(bytes: result, encoding: String.Encoding.utf8)!)
                
                expectation.fulfill()
            }
        } catch {
            XCTFail("testCat failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }

    func testPing() {
        
        let expectation = XCTestExpectation(description: "testPing")
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.ping(self.altNodeIdString) {
               result in
                
                if let pings = result.array {
                    for ping in pings {
                        print(ping.object?["Text"] ?? "-")
                        print(ping.object?["Time"] ?? "-")
                        print(ping.object?["Success"] ?? "-")
                    }
                }

                expectation.fulfill()
            }
        } catch {
            XCTFail("testPing failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testIds() {
        
        let idt1Expectation = XCTestExpectation(description: "testIds 1")
        let idt2Expectation = XCTestExpectation(description: "testIds 2")
        
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            let idString = self.nodeIdString
            
            try api.id(idString) { result in
                
                XCTAssert(result.object?[IpfsCmdString.ID.rawValue]?.string == idString)
                
                idt1Expectation.fulfill()
            }
        
            
            try api.id() {
                result in
                
                XCTAssert(result.object?["ID"]?.string == idString)
                idt2Expectation.fulfill()
            }
            
        } catch {
            XCTFail("testIds failed with error \(error)")
        }
        
        wait(for: [idt1Expectation, idt2Expectation], timeout: 15.0)
    }
    
    
    func testVersion() {
        
        let expectation = XCTestExpectation(description: "testVersion")
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.version() { version in
                
                XCTAssert(version == self.currentIpfsVersion)
                
                expectation.fulfill()
            }
        } catch {
            XCTFail("testVersion failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCommands() {
        
        let expectation = XCTestExpectation(description: "testCommands")
        do {

            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.commands(true) {
                result in
               
                // Short of having a gigantic (and regularly changing) table to
                // check against I don't know how to verify this. For now a
                // visual inspection will have to do.
                if let commands = result.object {
                    for (k,v) in commands {
                        print("k: ",k)
                        print("v: ",v)
                    }
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail("testCommands failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testStats() {

        let expectation = XCTestExpectation(description: "testStats")
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            try api.stats.bw() { result in
               
                /// We can't check for the values as they change constantly but at 
                /// least we can check for the keys being there.
                XCTAssert(result.object?["TotalIn"] != nil &&
                    result.object?["TotalOut"] != nil &&
                    result.object?["RateIn"] != nil &&
                    result.object?["RateOut"] != nil )
                
                expectation.fulfill()
            }
        } catch {
            XCTFail("testStats failed with error \(error)")
        }
    
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testLog() {
        
        let expectation = XCTestExpectation(description: "testLog")
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            let updateHandler = { (data: Data) -> Bool in
                print("Got an update. Closing.")
                return false
            }
            
            try api.log(updateHandler) {
                log in
                
                for entry in log {
                    print(entry)
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail("testLog failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testdns() {
        
        let expectation = XCTestExpectation(description: "testdns")
        
        do {
            let api       = try IpfsApi(addr: "/ip4/\(self.hostString)/tcp/\(self.hostPort)")
            let domain    = "ipfs.io"
            // Change domainHash to match whatever the actual hash of ipfs.io currently resolves to.
            let domainHash = "QmYNQJoKGNHTpPxCBPh9KkDpaExgd2duMa3aF6ytMpHdao"
            
            try api.dns(domain) { domainString in
                
                print("Domain: ",domainString)
                XCTAssert(domainString == "/ipfs/\(domainHash)")

                expectation.fulfill()
            }
        } catch {
            XCTFail("testdns failed with error \(error)")
        }
    
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testMount() {
        
        let expectation = XCTestExpectation(description: "testMount")

        do {
            let api       = try IpfsApi(addr: "/ip4/\(self.hostString)/tcp/\(self.hostPort)")
            
            try api.mount() {
                result in
                
                print("Mount got", result)
                XCTAssert(  result.object?["IPFS"]?.string == "/ipfs" &&
                            result.object?["IPNS"]?.string == "/ipns")
                expectation.fulfill()
            }
            
        } catch {
            XCTFail("testMount failed with error \(error)")
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testResolveIpfs() {
        
        let expectation = XCTestExpectation(description: "testResolveIpfs")
        do {
            let api       = try IpfsApi(addr: "/ip4/\(self.hostString)/tcp/\(self.hostPort)")
            let multihash = try fromB58String("QmeZy1fGbwgVSrqbfh9fKQrAWgeyRnj7h8fsHS1oy3k99x")
            
            try api.resolve("ipfs", hash: multihash, recursive: false) { result in
                
				XCTAssert(result.object?["Path"]?.string == "/ipfs/QmW2WQi7j6c7UgJTarActp7tDNikE4B2qXtFCfLPdsgaTQ")
                
                expectation.fulfill()
            }
        } catch {
            XCTFail()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testResolveIpns() {
        
        let expectation = XCTestExpectation(description: "testResolveIpns")
        do {
            let api       = try IpfsApi(addr: "/ip4/\(self.hostString)/tcp/\(self.hostPort)")
            let multihash = try fromB58String(self.nodeIdString)
            
            try api.resolve("ipns", hash: multihash, recursive: false) {
                result in
                
                // Replace the resolved string for your own.
                let resolvedIpnsString = "/ipfs/QmeVYFFc4gDmBkNB44RykvunsUFK777iYN1SH1J1VFYn15"
                
                XCTAssert(result.object?["Path"]?.string == resolvedIpnsString)
                
                expectation.fulfill()
            }
        } catch {
            XCTFail()
            print("Error in testResolveIpns \(error)")
        }
        wait(for: [expectation], timeout: 120.0)
    }
    

    
    
    func testAdd() {

//            let filePaths = [   "file:///Users/teo/tmp/outstream.txt",
//                                "file:///Users/teo/tmp/notred.png",
//                                "file:///Users/teo/tmp/game.jpg"]
//            let filePaths = [   "file:///Users/teo/Library/Services/FilesToIpfs.workflow"]
            let pathsToHashes = [   "file:///Users/teo/tmp/addtest/adir" : "QmY9Ks5KhpTZ6udF7F7Buq7gQ71aAKvynBXjHFhbpLLRrS",
                                "file:///Users/teo/tmp/addtest5" : "Qma97dios2R9rndBXyzfVmYEaCF8hkcyA6ULnw4WLu8Yk6"]
//            let filePaths = [   "file:///Users/teo/tmp/addtest5"]

        var testExpectations = [XCTestExpectation]()
        
        do {
            
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            for pathToHash in pathsToHashes {
        
                let expectation = XCTestExpectation(description: pathToHash.key)
                testExpectations.append(expectation)
                
                try api.add(pathToHash.key) {
                    result in
                    
                    /// Subtract one because last element is an empty directory to ignore
                    let resultCount = result.count
                    
                    for i in 0..<resultCount {
                        
                        print("Name: \(String(describing: result[i].name)) Hash:", b58String(result[i].hash!))
                        
                        if let hash = result[i].hash, b58String(hash) == pathToHash.value {
                            expectation.fulfill()
                            return
                        }
                    }
                    
                    // Did not find a match after going through all hashes in the result.
                    expectation.fulfill()
                    XCTFail()
                }
            }
        } catch {
            print("Error in testAdd: \(error)")
        }
        
        wait(for: testExpectations, timeout: 60.0)
    }
    
    func testAddData() {
        
        let content = "Awesome file content"
        let contentHash = "QmQKqsRQYuiEzAwxfZxppGBsN8knJAGvVSV3GhnrTrLpzm"
        let fileData = content.data(using: .utf8)
        let expectation = XCTestExpectation(description: "testAddData")
        
        do {
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            
            try api.add(fileData!) { result in
                
                guard result.count == 1, let hash = result[0].hash else {
                    XCTFail()
                    expectation.fulfill()
                    return
                }
                
                XCTAssert(b58String(hash) == contentHash)
                
                try? api.cat(hash) { result in
                    
                    let ipfsContent = String(bytes: result, encoding: String.Encoding.utf8)!
                    
                    XCTAssert(ipfsContent == content)
                    
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        } catch {
            print("Error in testAddData \(error)")
        }
    }
    
    func testRefs() {
        do {
            let multihash = try fromB58String("QmXsnbVWHNnLk3QGfzGCMy1J9GReWN7crPvY1DKmFdyypK")
            let api = try IpfsApi(host: self.hostString, port: self.hostPort)
            let expectation = XCTestExpectation(description: "testRefs")
            
            try api.refs(multihash, recursive: false) {
                result in
                
                XCTAssert(  result.count == 2 &&
                            b58String(result[0]) == "QmZX6Wrte3EqkUCwLHqBbuDhmH5yqPurNNTxKQc4NFfDxT" &&
                            b58String(result[1]) == "QmaLB324wDRKEJbGGr8FWg3qWnpTxdc2oEKDT62qhe8tMR" )
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        } catch {
            print("Error testRefs \(error)")
        }
    }
    
    
    
    /// Utility functions
    
    func tester(_ test: (_ dispatchGroup: DispatchGroup) throws -> Void) {
        
        let group = DispatchGroup()
        
        group.enter()
        
        do {
            /// Perform the test.
            try test(group)
            
        } catch  {
            XCTFail("tester error: \(error)")
        }
        
        _ = group.wait(timeout: DispatchTime.distantFuture)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
/** Template for test
do {
    let group = dispatch_group_create()
    dispatch_group_enter(group)

    let api = try IpfsApi(host: self.hostString, port: self.hostPort)
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
