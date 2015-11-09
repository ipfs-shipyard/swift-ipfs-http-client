//
//  Dictionary.swift
//  SwiftIpfsApi
//
//  Created by Teo on 09/11/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
import Foundation

/// To be able to map a dictionary we extend it 
/// (from github.com/thoughtbot/Argo project)

// pure merge for Dictionaries
func + <T, U>(var lhs: [T: U], rhs: [T: U]) -> [T: U] {
    for (key, val) in rhs {
        lhs[key] = val  /// Potential loss: Same key will lose existing lhs value.
    }
    
    return lhs
}

extension Dictionary {
    /// Apply function f to each value element in the dictionary and return
    /// a single merged dictionary with the result.
    func map<T>(f: Value -> T) -> [Key: T] {
        return self.reduce([:]) { $0 + [$1.0: f($1.1)] }
    }
}