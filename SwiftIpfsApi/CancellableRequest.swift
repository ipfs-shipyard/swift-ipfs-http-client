//
//  CancellableRequest.swift
//  SwiftIpfsApi
//
//  Created by Marcel Voß on 17.04.20.
//  Copyright © 2020 Teo Sartori. All rights reserved.
//

import Foundation

/// A protocol that represents any network request that can be cancelled during execution.
public protocol CancellableRequest {
    func cancel()
}

/// A concrete type conforming to the `CancellableRequest` protocol that can be used for abstracting inner implementation
/// details of the networking layer away and not leaking this kind of information to any integrators.
struct CancellableDataTask: CancellableRequest {
    private let request: URLSessionDataTask

    init(request: URLSessionDataTask) {
        self.request = request
    }

    func cancel() {
        request.cancel()
    }
}
