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
    case null
}


public extension JsonType {
    
    static func parse(_ json: AnyObject) -> JsonType {
        switch json {
        case let value as [AnyObject]: return .Array(value.map(parse))
            
        case let value as [Swift.String : AnyObject]: return .Object(value.map(parse))
            
        case let value as Swift.String: return .String(value)
            
        case let value as NSNumber: return .Number(value)
            
        case let value as JsonType: return value
            
        default: return .null
        }
    }
}

/// Use introspection to make the extraction of the value easier.
public extension JsonType {
    
    var string: Swift.String? {
        switch self {
        case .String(let string): return string
        default: return nil
        }
    }
    
    var number: NSNumber? {
        switch self {
        case .Number(let number): return number
        default: return nil
        }
    }
    
    var object: [Swift.String : JsonType]? {
        switch self {
        case .Object(let object): return object
        default: return nil
        }
    }
    
    var array: [JsonType]? {
        switch self {
        case .Array(let array): return array
        default: return nil
        }
    }
}
