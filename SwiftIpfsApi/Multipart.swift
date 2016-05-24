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
    
    private static let lineFeed:String = "\r\n"
    private let boundary: String
    private let charset: String
    private var body = NSMutableData()
    private let request: NSMutableURLRequest
    
    init(targetUrl: String, charset: String) throws {
        
        self.charset = charset
        boundary     = Multipart.createBoundary()

        guard let url = NSURL(string: targetUrl) else { throw MultipartError.FailedURLCreation }
        request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("multipart/form-data; boundary="+boundary, forHTTPHeaderField: "content-type")
        request.setValue("Swift IPFS Client", forHTTPHeaderField: "user-agent")
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
            count -= 1
        } while count > 0
        
        return output
    }
    
    public static func addFilePart(oldMultipart: Multipart, fileName: String?, fileData: NSData) throws -> Multipart {
        var outString = "--" + oldMultipart.boundary + lineFeed
        oldMultipart.body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        if fileName != nil {
            outString = "content-disposition: file; name=file; filename=\(fileName!)" + lineFeed
        } else {
            outString = "content-disposition: file; name=file;" + lineFeed
        }
        oldMultipart.body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        outString = "content-type: application/octet-stream" + lineFeed
        oldMultipart.body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        outString = "content-transfer-encoding: binary" + lineFeed + lineFeed
        oldMultipart.body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        /// Add the actual data for this file.
        oldMultipart.body.appendData(fileData)
        oldMultipart.body.appendData(lineFeed.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        return oldMultipart
    }
    
    public static func finishMultipart(multipart: Multipart, completionHandler: (NSData) -> Void) {
        
        let outString = "--" + multipart.boundary + "--" + lineFeed
        multipart.body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        multipart.request.setValue(String(multipart.body.length), forHTTPHeaderField: "content-length")
        multipart.request.HTTPBody = multipart.body
        
        
        /// Send off the request
        let task = NSURLSession.sharedSession().dataTaskWithRequest(multipart.request) {
            (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            
            guard error == nil && data != nil else {
                print("Error in dataTaskWithRequest: \(error)")//throw HttpIoError.TransmissionError("fail: \(error)")
                return
            }
            
            completionHandler(data!)
            
        }
        
        task.resume()
    }
}