//
//  JsonType.swift
//  SwiftIpfsApi
//
//  Created by Teo on 09/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//

import Foundation

public enum JsonType {
    case Object([Swift.String : JsonType])
    case Array([JsonType])
    case String(Swift.String)
    case Number(NSNumber)
    case Null
}


public extension JsonType {
    static func parse(json: AnyObject) -> JsonType {
        switch json {
        case let value as [AnyObject]: return .Array(value.map(parse))
            
        case let value as [Swift.String : AnyObject]: return .Object(value.map(parse))
            
        case let value as Swift.String: return .String(value)
            
        case let value as NSNumber: return .Number(value)
        default: return .Null
        }
    }
}