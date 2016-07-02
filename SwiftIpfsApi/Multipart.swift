//
//  Multipart.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 20/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation
public enum MultipartError : ErrorProtocol {
    case failedURLCreation
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

        guard let url = URL(string: targetUrl) else { throw MultipartError.failedURLCreation }
        request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
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
            output += String(allowed.characters[allowed.characters.index(allowed.startIndex, offsetBy: r)])
			count -= 1
        } while count > 0
        
        return output
    }
    
    public static func addFilePart(_ oldMultipart: Multipart, fileName: String?, fileData: Data) throws -> Multipart {
        var outString = "--" + oldMultipart.boundary + lineFeed
        oldMultipart.body.append(outString.data(using: String.Encoding.utf8)!)
        
        if fileName != nil {
            outString = "content-disposition: file; name=file; filename=\(fileName!)" + lineFeed
        } else {
            outString = "content-disposition: file; name=file;" + lineFeed
        }
        oldMultipart.body.append(outString.data(using: String.Encoding.utf8)!)
        
        outString = "content-type: application/octet-stream" + lineFeed
        oldMultipart.body.append(outString.data(using: String.Encoding.utf8)!)
        
        outString = "content-transfer-encoding: binary" + lineFeed + lineFeed
        oldMultipart.body.append(outString.data(using: String.Encoding.utf8)!)
        
        /// Add the actual data for this file.
        oldMultipart.body.append(fileData)
        oldMultipart.body.append(lineFeed.data(using: String.Encoding.utf8)!)
        
        return oldMultipart
    }
    
    public static func finishMultipart(_ multipart: Multipart, completionHandler: (Data) -> Void) {
        
        let outString = "--" + multipart.boundary + "--" + lineFeed
        multipart.body.append(outString.data(using: String.Encoding.utf8)!)
        
        multipart.request.setValue(String(multipart.body.length), forHTTPHeaderField: "content-length")
        multipart.request.httpBody = multipart.body as Data
        
        
        /// Send off the request
        let task = URLSession.shared().dataTask(with: (multipart.request as URLRequest)) {
            (data: Data?, response: URLResponse?, error: NSError?) -> Void in
            
            guard error == nil && data != nil else {
                print("Error in dataTaskWithRequest: \(error)")//throw HttpIoError.TransmissionError("fail: \(error)")
                return
            }
            
            completionHandler(data!)
            
        }
        
        task.resume()
    }
}
