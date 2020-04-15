//
//  JsonType.swift
//  SwiftIpfsApi
//
//  Created by Teo on 09/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//

import Foundation

public enum JsonType {
    case object([String: JsonType])
    case array([JsonType])
    case string(String)
    case number(NSNumber)
    case null
}


public extension JsonType {
    
    static func parse(_ json: AnyObject) -> JsonType {
        switch json {
        case let value as [AnyObject]: return .array(value.map(parse))
            
        case let value as [String: AnyObject]: return .object(value.map(parse))
            
        case let value as String: return .string(value)
            
        case let value as NSNumber: return .number(value)
            
        case let value as JsonType: return value
            
        default: return .null
        }
    }
}

/// Use introspection to make the extraction of the value easier.
public extension JsonType {
    var string: String? {
        switch self {
        case .string(let string): return string
        default: return nil
        }
    }
    
    var number: NSNumber? {
        switch self {
        case .number(let number): return number
        default: return nil
        }
    }
    
    var object: [String: JsonType]? {
        switch self {
        case .object(let object): return object
        default: return nil
        }
    }
    
    var array: [JsonType]? {
        switch self {
        case .array(let array): return array
        default: return nil
        }
    }
}
