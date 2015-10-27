//
//  Multipart.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 20/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation
public enum MultipartError : ErrorType {
    case FailedURLCreation
}

public struct Multipart {
    
    private static let LINE_FEED:String = "\r\n"
    private let boundary: String
//    private let httpConnection: NSURLConnection
    private let charset: String
    
    
    init(request: String, charset: String) throws {
        
        self.charset = charset
        boundary     = Multipart.createBoundary()

        
        guard let url = NSURL(string: request) else { throw MultipartError.FailedURLCreation }
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("multipart/form-data; boundary="+boundary, forHTTPHeaderField: "content-type")
        request.setValue("Swift IPFS Client", forHTTPHeaderField: "user-agent")
//
//            let task = NSURLSession.sharedSession().dataTaskWithURL(url) {
//                (data: NSData?, response: NSURLResponse?, error: NSError?) in
//                
//                print("The peers:",NSString(data: data!, encoding: NSUTF8StringEncoding))
//            }
//            
//            task.resume()
//        }

    }
}



extension Multipart {
    /// Generate a string of 32 random alphanumeric characters.
    static func createBoundary() -> String {
    
        let allowed     = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let maxCount    = allowed.characters.count
        
        var count       = 32
        var output      = ""
        
        repeat {
            let r = Int(arc4random_uniform(UInt32(maxCount)))
            output += String(allowed.characters[allowed.startIndex.advancedBy(r)])
        } while --count > 0
        
        return output
    }
}