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

    var hostString      = "127.0.0.1"
    let hostPort        = 5001
    
    /// Your own IPNS node hash
    let nodeIdString    = "QmWNwhBWa9sWPvbuS5XNaLp6Phh5vRN77BZRF5xPWG3FN1"
    
    /// Another known neighbouring hash
    let altNodeIdString = "QmSoLnSGccFuZQJzRadHn95W2CrSFmZuTdDWP8HXaHca9z"

    let peerIPAddr = "/ip4/10.12.0.8/tcp/4001"
    
    let currentIpfsVersion = "0.4.14"
    
    // FIX: Fails due to issue in Multihash not recognizing new non Qm style hashes.
    func testRefsLocal() throws {
        let completionExpectation = expectation(description: "testRefsLocal")

        let api = try IpfsApi(host: self.hostString, port: self.hostPort)

        api.refs.local { result in
            XCTAssertNotNil(result.getOrNil())
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 100.0)
    }
    
    // FIX: Fails due to issue in Multihash not recognizing new non Qm style hashes.
    func testPin() throws {
        let pinAddExpectation = expectation(description: "testPinAdd")
        let pinLsExpectation = expectation(description: "testPinLs")
        let pinRmExpectation = expectation(description: "testPinRm")

        let api = try IpfsApi(host: hostString, port: hostPort)
        let multihash = try fromB58String("Qmb4b83vuYMmMYqj5XaucmEuNAcwNBATvPL6CNuQosjr91")

        api.pin.add(multihash) { pinnedHashes in
            XCTAssertNotNil(pinnedHashes.getOrNil())
            pinAddExpectation.fulfill()

            // Pin Ls. Visual inspection for now. Change to check for added pin.
            api.pin.ls { result in
                XCTAssertNotNil(result.getOrNil())
                pinLsExpectation.fulfill()

                // Pin Rm. Remove previously pinned hash.
                api.pin.rm(multihash) { removed in
                    pinRmExpectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 50.0)
    }
    
    func testRepo() throws {
        let lsExpectation = expectation(description: "ls")
        let repoGcExpectation = expectation(description: "testRepoGc")

        let api = try IpfsApi(host: hostString, port: hostPort)

        /** First we do an ls of something we know isn't pinned locally.
         This causes it to be copied to the local node so that the gc has
         something to collect. */

        let multihash = try fromB58String("QmTtqKeVpgQ73KbeoaaomvLoYMP7XKemhTgPNjasWjfh9b")
        
        api.ls(multihash) { _ in
            lsExpectation.fulfill()

            api.repo.gc { result in
                repoGcExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 300)
    }

    func testBlock() throws {
        let blockPutExpectation = expectation(description: "testBlockPut")
        let blockGetExpectation = expectation(description: "testBlockGet")
        let blockStatExpectation = expectation(description: "testBlockStat")

        let api = try IpfsApi(host: hostString, port: hostPort)
        let rawData: [UInt8] = Array("hej verden".utf8)

        api.block.put(rawData) { result in
            guard let node = try? result.get() else {
                XCTFail()
                return
            }

            XCTAssert(b58String(node.hash!) == "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")
            blockPutExpectation.fulfill()
        }

        // Block Get.
        var multihash = try fromB58String("QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")

        api.block.get(multihash) { result in
            guard let hashes = try? result.get() else {
                XCTFail()
                return
            }

            let res = String(bytes: hashes, encoding: .utf8)
            XCTAssert(res == "hej verden")
            blockGetExpectation.fulfill()
        }

        // Block Stat.
        multihash = try fromB58String("QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw")

        api.block.stat(multihash) { result in
            guard let json = try? result.get() else {
                XCTFail()
                return
            }

            let hash = json.object?["Key"]?.string
            let size = json.object?["Size"]?.number

            if hash == nil || size == nil
                || hash != "QmR4MtZCAUkxzg8ewgNp6hDVgtqnyojDSWVF4AFG9RWsYw"
                || size != 10 {
                XCTFail()
            }
            blockStatExpectation.fulfill()
        }

        waitForExpectations(timeout: 50.0)
    }
    
    func testObject() throws {
        let objNewExpectation = expectation(description: "testObjectNew")
        let objPutExpectation = expectation(description: "testObjectPut")
        let objGetExpectation = expectation(description: "testObjectGet")
        let objLinksExpectation = expectation(description: "testObjectLinks")

        let api = try IpfsApi(host: hostString, port: hostPort)
        api.object.new() { result in
            guard let node = try? result.get() else {
                XCTFail()
                return
            }

            /// A new ipfs object always has the same hash so we can assert against it.
            XCTAssert(b58String(node.hash!) == "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n")
            objNewExpectation.fulfill()
        }

        // Test Object Put
        let data = [UInt8]("{ \"Data\" : \"Dauz\" }".utf8)

        api.object.put(data) { result in
            guard let node = try? result.get() else {
                XCTFail()
                return
            }

            XCTAssert(b58String(node.hash!) == "QmUqvXbE4s9oTQNhBXm2hFapLq1pnuuxsMdxP9haTzivN6")
            objPutExpectation.fulfill()
        }

        // Test Object Get
        var multihash = try fromB58String("QmUqvXbE4s9oTQNhBXm2hFapLq1pnuuxsMdxP9haTzivN6")

        api.object.get(multihash) { result in
            guard let node = try? result.get() else {
                XCTFail()
                return
            }

            XCTAssertEqual(node.data!, Array("Dauz".utf8))
            objGetExpectation.fulfill()
        }

        // Test Object Links
        multihash = try fromB58String("QmR3azp3CCGEFGZxcbZW7sbqRFuotSptcpMuN6nwThJ8x2")

        api.object.links(multihash) { result in
            guard let node = try? result.get() else {
                XCTFail()
                return
            }

            // There should be two links off the root:
            if let links = node.links, links.count == 2 {
                XCTAssertEqual(b58String(links[0].hash!), "QmWfzntFwgPf9T9brQ6P2PL1BMoH16jZvhanGYtZQfgyaD")
                XCTAssertEqual(b58String(links[1].hash!), "QmRJ8Gngb5PmvoYDNZLrY6KujKPa4HxtJEXNkb5ehKydg2")
            } else {
                XCTFail()
            }
            objLinksExpectation.fulfill()
        }

        waitForExpectations(timeout: 50.0)
    }

    func testObjectPatch() throws {
        let objNewExpectation = expectation(description: "testObjectNew")
        let objPatchExpectation = expectation(description: "testObjectPatch")
        let objLinksExpectation = expectation(description: "testObjectLinks")

        let api = try IpfsApi(host: hostString, port: hostPort)

        // Get the empty directory object to start off with.
        api.object.new { result in
            let node = result.getOrNil()
            XCTAssertNotNil(node)

            let data = "This is a longer message."
            api.object.patch(node!.hash!, cmd: .setData, args: data) { result in
                objNewExpectation.fulfill()

                // The previous hash that was returned from setData
                let previousMultihash = try? fromB58String("QmQXys2Xv5xiNBR21F1NNwqWC5cgHDnndKX4c3yXwP4ywj")
                // Get the empty directory object to start off with.

                let data = " Addition to the message."
                api.object.patch(previousMultihash!, cmd: .appendData, args: data) { result in
                    let node = result.getOrNil()

                    // Now we request the data from the new Multihash to compare it.
                    api.object.data(node!.hash!) { result in
                        guard let bytes = result.getOrNil() else {
                            XCTFail()
                            return
                        }

                        let resultString = String(bytes: bytes, encoding: .utf8)
                        XCTAssertEqual(resultString, "This is a longer message. Addition to the message.")

                        objPatchExpectation.fulfill()

                        let hash = "QmUYttJXpMQYvQk5DcX2owRUuYJBJM6W7KQSUsycCCE2MZ" // a file
                        let hash2 = "QmVtU7ths96fMgZ8YSZAbKghyieq7AjxNdcqyVzxTt3qVe" // a directory

                        // Get the empty directory object to start off with.
                        api.object.new(.unixFsDir) { result in
                            let node = result.getOrNil()
                            XCTAssertNotNil(node)

                            /** This uses the directory object to create a new object patched
                             with the object of the given hash. */
                            api.object.patch(node!.hash!, cmd: .addLink, args: "foo", hash) { result in
                                let node = result.getOrNil()
                                XCTAssertNotNil(node)

                                // Get a new object from the previous object patched with the object of hash2
                                api.object.patch(node!.hash!, cmd: .addLink, args: "ars", hash2) { result in
                                    let node = result.getOrNil()

                                    // get the new object's links to check against.
                                    api.object.links(node!.hash!) { result in
                                        let node = result.getOrNil()

                                        // Check that the object's link is the same as
                                        // what we originally passed to the patch command.

                                        let links = node?.links
                                        XCTAssertEqual(links?.count, 2)
                                        XCTAssertNotNil(links)

                                        guard let linkHash = links?[1].hash else {
                                            XCTFail()
                                            return
                                        }
                                        XCTAssertEqual(b58String(linkHash), hash)

                                        // Now try to remove it and check that we only have one link.
                                        api.object.patch(node!.hash!, cmd: .rmLink, args: "foo") { result in
                                            let node = result.getOrNil()
                                            XCTAssertNotNil(node)

                                            // get the new object's links to check against.
                                            api.object.links(node!.hash!) { result in
                                                guard let links = result.getOrNil()?.links else {
                                                    XCTFail()
                                                    return
                                                }

                                                XCTAssertEqual(links.count, 1)

                                                let linkHash = links[0].hash
                                                XCTAssertNotNil(linkHash)
                                                XCTAssertEqual(b58String(linkHash!), hash2)

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

        waitForExpectations(timeout: 50.0)
    }
    
    func testNameResolve() throws {
        let nameResolveExpectation = expectation(description: "testNameResolve")
        let namePublishExpectation = expectation(description: "testNamePublish")
        let nameResolve2Expectation = expectation(description: "testNameResolve2")

        var idHash: String = ""
        // Start test by storing the existing hash so we can restore it after testing.

        let api = try IpfsApi(host: hostString, port: hostPort)
        api.name.resolve { result in
            guard let name = result.getOrNil() else {
                XCTFail()
                return
            }

            idHash = name.replacingOccurrences(of: "/ipfs/", with: "")

            nameResolveExpectation.fulfill()

            let publishedPath = "/ipfs/" + idHash
            api.name.publish(ipfsPath: publishedPath) { result in
                let json = result.getOrNil()

                XCTAssertEqual(json?.object?["Name"]?.string, self.nodeIdString)
                XCTAssertEqual(json?.object?["Value"]?.string, publishedPath)

                namePublishExpectation.fulfill()

                api.name.resolve { result in
                    let path = result.getOrNil()
                    XCTAssertNotNil(path)

                    XCTAssertEqual(path, publishedPath)
                    nameResolve2Expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 250.0)
    }
    
    
    // Fails on timeout because the api doesn't return – it keeps looking.
    func testDhtFindProvs() {

        let expectation = XCTestExpectation(description: "testFindProvs")
        do {
            // Common
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
    func testDhtQuery() throws {
        let completionExpectation = expectation(description: "testDhtQuery")

        let api = try IpfsApi(host: hostString, port: hostPort)
        let neighbour = altNodeIdString

        // This nearest works for me but may need changing to something local to the tester.
        let nearest = try fromB58String(neighbour)

        api.dht.query(nearest) { result in
            // TODO: assert against some known return value
            XCTAssertNotNil(result.getOrNil())
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 120.0)
    }
    
    func testDhtFindPeer() throws {
        let completionExpectation = expectation(description: "testDhtFindPeer")

        let api = try IpfsApi(host: hostString, port: hostPort)
        let neighbour = altNodeIdString

        // This peer works for me but may need changing to something local to the tester.
        let peer = try fromB58String(neighbour)

        // At the moment the findpeer wraps the stream json in an array
        api.dht.findpeer(peer) { result in
            guard
                let json = result.getOrNil(),
                let resArray = json.object?["Responses"]?.array else {
                    XCTFail()
                    return
            }

            for res in resArray {
                XCTAssertEqual(res.object?["ID"]?.string, neighbour)
            }

            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
    
    // If this fails check from the command line that the ipns path actually resolves
    // to the checkHash before thinking this is actually broken. Ipns links do change.
    func testFileLs() throws {
        let ipnsExpectation = expectation(description: "testIpnsLs")
        let ipfsExpectation = expectation(description: "testIpfsLs")

        let api = try IpfsApi(host: hostString, port: hostPort)
        // basedir hash
        var path = "/ipns/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ"

        // lvl2file hash
        let checkIpnsHash = "QmV1imZz8VRiYFw7ZSSUtTFtcaYA5iJXURkxLhEJssBXvy"

        api.file.ls(path) { result in
            let foundHash = result.getOrNil()?.object?["Objects"]?.object?[checkIpnsHash]?.object?["Hash"]?.string
            XCTAssertNotNil(foundHash)

            XCTAssertEqual(foundHash, checkIpnsHash)

            ipnsExpectation.fulfill()
        }

        let objHash = "QmQuQzFkULYToUBrMtyHg2tjvcd93N4kNHPCxfcFthB2kU"
        let checkIpfsHash = "QmQHAVCpAQxU21bK8VxeWisn19RRC4bLNFV4DiyXDDyLXM"
        path = "/ipfs/" + objHash

        api.file.ls(path) { result in
            let hash = result.getOrNil()?.object?["Objects"]?.object?[objHash]?.object?["Links"]?.array?[0].object?["Hash"]?.string

            XCTAssertNotNil(hash)
            XCTAssertEqual(hash, checkIpfsHash)

            ipfsExpectation.fulfill()
        }

        waitForExpectations(timeout: 35.0)
    }
    
    func testBootstrap() throws {
        let trustedPeer = "/ip4/104.131.131.82/tcp/4001/ipfs/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ"
        let trustedPeer2 = "/ip4/104.236.176.52/tcp/4001/ipfs/QmSoLnSGccFuZQJzRadHn95W2CrSFmZuTdDWP8HXaHca9z"

        let bootstrapRmExpectation = expectation(description: "testBootstrapRm")
        let bootstrapListExpectation = expectation(description: "testBootstrapList")
        let bootstrapAddExpectation = expectation(description: "testBootstrapAdd")

        let tpMultiaddr = try newMultiaddr(trustedPeer)
        let tpMultiaddr2 = try newMultiaddr(trustedPeer2)

        let api = try IpfsApi(host: hostString, port: hostPort)

        let tPeers = [tpMultiaddr, tpMultiaddr2]

        api.bootstrap.list { peers in
            XCTAssertNotNil(peers.getOrNil())
            bootstrapListExpectation.fulfill()
        }

        api.bootstrap.add(tPeers) { result in
            let peers = result.getOrNil()
            XCTAssertNotNil(peers)

            XCTAssertEqual(peers?.count, 2)
            XCTAssertEqual(try? peers?[0].string(), trustedPeer)
            XCTAssertEqual(try? peers?[1].string(), trustedPeer2)

            bootstrapAddExpectation.fulfill()

            api.bootstrap.rm(tPeers) { result in
                let peers = result.getOrNil()
                XCTAssertNotNil(peers)

                XCTAssertEqual(peers?.count, 2)
                XCTAssertEqual(try? peers?[0].string(), trustedPeer)
                XCTAssertEqual(try? peers?[1].string(), trustedPeer2)

                bootstrapRmExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }
    
    func testSwarmPeers() throws {
        // NB: This test will require the user to change the knownPeer to a known peer.
        let knownPeer = peerIPAddr + "/ipfs/" + altNodeIdString
        
        let completionExpectation = expectation(description: "testSwarmPeers")

        let api = try IpfsApi(host: hostString, port: hostPort)
        api.swarm.peers { result in
            guard let peers = try? result.get() else {
                XCTFail()
                return
            }

            XCTAssertTrue(peers.allSatisfy { (try? $0.string()) ?? "" == knownPeer })
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
    
    func testSwarmAddrs() throws {
        let completionExpectation = expectation(description: "testSwarmAddrs")

        let api = try IpfsApi(host: hostString, port: hostPort)

        api.swarm.addrs { result in
            guard
                let addrs = try? result.get(),
                let safeAdress = addrs.object?[self.altNodeIdString]?.array?[0].string else {
                    XCTFail()
                    return
            }

            XCTAssertEqual(safeAdress, self.peerIPAddr)
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }

    func testSwarmConnect() throws {
        let completionExpectation = expectation(description: "testSwarmConnect")

        let api = try IpfsApi(host: hostString, port: hostPort)

        // NB: This test will require the user to change the peerAddress to a known peer.
        let peerAddress =  peerIPAddr + "/ipfs/" + altNodeIdString
        let expectedMessage = "connect \(altNodeIdString) success"

        api.swarm.connect(peerAddress) { result in
            let json = result.getOrNil()
            XCTAssertNotNil(json)

            let msg = json?.object?["Strings"]?.array?[0].string
            XCTAssertNotNil(msg)
            XCTAssertEqual(msg, expectedMessage)

            // Not currently working as expected due to circuit relay implementation.
            // see https://discuss.ipfs.io/t/ipfs-swarm-disconnect-failure-conn-not-found/2553/6
            api.swarm.disconnect(peerAddress) { result in
                let json = result.getOrNil()
                XCTAssertNotNil(json)

                let msg = json?.object?["Strings"]?.array?[0].string
                XCTAssertNotNil(msg)
                XCTAssertEqual(msg, "dis" + expectedMessage)

                completionExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    func testDiag() throws {
        let completionExpectation = expectation(description: "testDiagSys")

        let api = try IpfsApi(host: hostString, port: hostPort)

        api.diag.sys() { result in
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testConfig() throws {
        let configShowExpectation = expectation(description: "testConfigShow")

        let api = try IpfsApi(host: hostString, port: hostPort)

        api.config.show() { result in
            XCTAssertNotNil(result.getOrNil())

            /// do comparison with truth here. Currently by visual inspection :/
            configShowExpectation.fulfill()
        }

        let configSetExpectation = expectation(description: "testConfigSet")
        let configSetGetExpectation = expectation(description: "setGetExpectation")

        // Set a value in the config and read back the same to confirm.
        api.config.set("Teo", value: "42") { result in
            configSetExpectation.fulfill()

            api.config.get("Teo") { result in
                let json = result.getOrNil()
                XCTAssertNotNil(json)

                XCTAssertEqual(json?.string, "42")

                configSetGetExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 25.0)
    }
    
    
    func testLs() throws {
        let completionExpectation = expectation(description: "testLs")

        let multihash = try fromB58String("QmPXME1oRtoT627YKaDPDQ3PwA8tdP9rWuAAweLzqSwAWT")
        let api = try IpfsApi(host: self.hostString, port: self.hostPort)
        api.ls(multihash) { results in
            guard
                let nodes = try? results.get(),
                let links = nodes.first?.links else {
                    XCTFail()
                    return
            }

            XCTAssertEqual(links.count, 5)
            XCTAssertEqual(links[0].name, "contact")
            XCTAssertEqual(links[1].name, "help")
            XCTAssertEqual(links[2].name, "quick-start")
            XCTAssertEqual(links[3].name, "readme")
            XCTAssertEqual(links[4].name, "security-notes")

            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
        
    func testCat() throws {
        let completionExpectation = XCTestExpectation(description: "testCat")

        let multihash = try fromB58String("QmYeQA5P2YuCKxZfSbjhiEGD3NAnwtdwLL6evFoVgX1ULQ")
        let api = try IpfsApi(host: hostString, port: hostPort)

        api.cat(multihash) { _ in
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }

    func testPing() throws {
        let completionExpectation = expectation(description: "testPing")

        let api = try IpfsApi(host: hostString, port: hostPort)

        api.ping(altNodeIdString) { result in
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 15.0)
    }
    
    func testIds() throws {
        let idt1Expectation = expectation(description: "testIds 1")
        let idt2Expectation = expectation(description: "testIds 2")

        let api = try IpfsApi(host: hostString, port: hostPort)
        let idString = nodeIdString

        api.id(idString) { result in
            let json = result.getOrNil()
            XCTAssertNotNil(json)

            XCTAssertEqual(json?.object?[IpfsCmdString.ID.rawValue]?.string, idString)

            idt1Expectation.fulfill()
        }

        api.id { result in
            let json = result.getOrNil()
            XCTAssertNotNil(json)

            XCTAssertEqual(json?.object?["ID"]?.string, idString)
            idt2Expectation.fulfill()
        }

        waitForExpectations(timeout: 15.0)
    }
    
    
    func testVersion() throws {
        let completionExpectation = expectation(description: "testVersion")

        let api = try IpfsApi(host: hostString, port: hostPort)
        api.version { result in
            let version = result.getOrNil()
            XCTAssertNotNil(version)

            XCTAssertEqual(version, self.currentIpfsVersion)
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
    
    func testCommands() throws {
        let completionExpectation = expectation(description: "testCommands")

            let api = try IpfsApi(host: hostString, port: hostPort)
            api.commands(true) { result in
                XCTAssertNotNil(result.getOrNil())
                completionExpectation.fulfill()
            }

        waitForExpectations(timeout: 5.0)
    }
    
    func testStats() throws {
        let completionExpectation = expectation(description: "testStats")

        let api = try IpfsApi(host: hostString, port: hostPort)

        api.stats.bw { result in
            /// We can't check for the values as they change constantly but at
            /// least we can check for the keys being there.

            let json = result.getOrNil()
            XCTAssertNotNil(json)
            XCTAssertNotNil(json?.object?["TotalIn"])
            XCTAssertNotNil(json?.object?["TotalOut"])
            XCTAssertNotNil(json?.object?["RateIn"])
            XCTAssertNotNil(json?.object?["RateOut"])

            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
    
    func testLog() throws {
        let completionExpectation = expectation(description: "testLog")

        let api = try IpfsApi(host: hostString, port: hostPort)
        let updateHandler = { (data: Data) -> Bool in
            return false
        }

        try api.log(updateHandler) { log in
            completionExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }
    
    func testdns() throws {
        let completionExpectation = expectation(description: "testdns")

            let api = try IpfsApi(addr: "/ip4/\(hostString)/tcp/\(hostPort)")
            let domain = "ipfs.io"

            // Change domainHash to match whatever the actual hash of ipfs.io currently resolves to.
            let domainHash = "QmYNQJoKGNHTpPxCBPh9KkDpaExgd2duMa3aF6ytMpHdao"
            
            api.dns(domain) { result in
                let domainString = result.getOrNil()
                XCTAssertNotNil(domainString)

                XCTAssertEqual(domainString, "/ipfs/\(domainHash)")
                completionExpectation.fulfill()
            }

        waitForExpectations(timeout: 120.0)
    }
    
    func testMount() throws {
        let completionExpectation = expectation(description: "testMount")

        let api = try IpfsApi(addr: "/ip4/\(hostString)/tcp/\(hostPort)")

        api.mount { result in
            let json = result.getOrNil()
            XCTAssertNotNil(json)

            XCTAssertEqual(json?.object?["IPFS"]?.string, "/ipfs")
            XCTAssertEqual(json?.object?["IPNS"]?.string, "/ipns")

            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 120.0)
    }
    
    func testResolveIpfs() throws {
        let completionExpectation = expectation(description: "testResolveIpfs")

        let api = try IpfsApi(addr: "/ip4/\(hostString)/tcp/\(hostPort)")
        let multihash = try fromB58String("QmeZy1fGbwgVSrqbfh9fKQrAWgeyRnj7h8fsHS1oy3k99x")

        api.resolve("ipfs", hash: multihash, recursive: false) { result in
            guard let json = try? result.get() else {
                XCTFail()
                return
            }

            XCTAssertEqual(json.object?["Path"]?.string, "QmW2WQi7j6c7UgJTarActp7tDNikE4B2qXtFCfLPdsgaTQ")
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 120.0)
    }
    
    func testResolveIpns() throws {
        let completionExpectation = expectation(description: "testResolveIpns")

        let api = try IpfsApi(addr: "/ip4/\(hostString)/tcp/\(hostPort)")
        let multihash = try fromB58String(nodeIdString)

        api.resolve("ipns", hash: multihash, recursive: false) { result in
            guard let json = try? result.get() else {
                XCTFail()
                return
            }

            // Replace the resolved string for your own.
            let resolvedIpnsString = "/ipfs/QmeVYFFc4gDmBkNB44RykvunsUFK777iYN1SH1J1VFYn15"
            XCTAssertEqual(json.object?["Path"]?.string, resolvedIpnsString)

            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 120.0)
    }
    
    func testAdd() throws {

//            let filePaths = [   "file:///Users/teo/tmp/outstream.txt",
//                                "file:///Users/teo/tmp/notred.png",
//                                "file:///Users/teo/tmp/game.jpg"]
//            let filePaths = [   "file:///Users/teo/Library/Services/FilesToIpfs.workflow"]
            let pathsToHashes = [   "file:///Users/teo/tmp/addtest/adir" : "QmY9Ks5KhpTZ6udF7F7Buq7gQ71aAKvynBXjHFhbpLLRrS",
                                "file:///Users/teo/tmp/addtest5" : "Qma97dios2R9rndBXyzfVmYEaCF8hkcyA6ULnw4WLu8Yk6"]
//            let filePaths = [   "file:///Users/teo/tmp/addtest5"]

        let api = try IpfsApi(host: hostString, port: hostPort)

        for pathToHash in pathsToHashes {
            let completionExpectation = expectation(description: pathToHash.key)

            api.add(pathToHash.key) { result in
                guard let nodes = result.getOrNil() else {
                    XCTFail()
                    return
                }

                // Subtract one because last element is an empty directory to ignore
                for i in 0..<nodes.count {
                    if let hash = nodes[i].hash, b58String(hash) == pathToHash.value {
                        completionExpectation.fulfill()
                        return
                    }
                }
            }
        }

        waitForExpectations(timeout: 60.0)
    }
    
    func testAddData() throws {
        let content = "Awesome file content"
        let contentHash = "QmQKqsRQYuiEzAwxfZxppGBsN8knJAGvVSV3GhnrTrLpzm"
        let fileData = content.data(using: .utf8)
        let completionExpectation = expectation(description: "testAddData")

        let api = try IpfsApi(host: hostString, port: hostPort)
        
        api.add(fileData!) { result in
            let nodes = result.getOrNil()
            XCTAssertNotNil(nodes)
            XCTAssertEqual(nodes?.count, 1)

            guard let hash = nodes?.first?.hash else {
                XCTFail()
                return
            }

            XCTAssertEqual(b58String(hash), contentHash)
            
            api.cat(hash) { result in
                guard let bytes = result.getOrNil() else {
                    XCTFail()
                    return
                }

                let ipfsContent = String(bytes: bytes, encoding: .utf8)!
                XCTAssertEqual(ipfsContent, content)
                
                completionExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testRefs() throws {
        let multihash = try fromB58String("QmXsnbVWHNnLk3QGfzGCMy1J9GReWN7crPvY1DKmFdyypK")
        let api = try IpfsApi(host: hostString, port: hostPort)
        let completionExpectation = expectation(description: "testRefs")

        api.refs(multihash, recursive: false) { result in
            guard let hashes = result.getOrNil() else {
                XCTFail()
                return
            }

            XCTAssertEqual(hashes.count, 2)
            XCTAssertEqual(b58String(hashes[0]), "QmZX6Wrte3EqkUCwLHqBbuDhmH5yqPurNNTxKQc4NFfDxT")
            XCTAssertEqual(b58String(hashes[1]), "QmaLB324wDRKEJbGGr8FWg3qWnpTxdc2oEKDT62qhe8tMR")

            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Utility functions
    
    func tester(_ test: (_ dispatchGroup: DispatchGroup) throws -> Void) {
        let group = DispatchGroup()
        
        group.enter()
        
        do {
            try test(group)
        } catch  {
            XCTFail("tester error: \(error)")
        }
        
        _ = group.wait(timeout: DispatchTime.distantFuture)
    }
    
}

extension Result {
    func getOrNil() -> Success? {
        return try? self.get()
    }
}
