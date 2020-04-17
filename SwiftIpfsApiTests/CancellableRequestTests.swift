//
//  CancellableRequestTests.swift
//  SwiftIpfsApiTests
//
//  Created by Marcel Voß on 17.04.20.
//  Copyright © 2020 Teo Sartori. All rights reserved.
//

import XCTest

class CancellableRequestTests: XCTestCase {

    func testCancellableRequest() {
        let task = MockURLSessionDataTask()

        let cancellationExpectation = expectation(description: "expected to cancel network request")

        task.onCancel = {
            cancellationExpectation.fulfill()
        }

        task.cancel()

        waitForExpectations(timeout: 1.0)
    }

}

private class MockURLSessionDataTask: URLSessionDataTask {
    var onCancel: (() -> Void)?

    override func cancel() {
        onCancel?()
    }
}
