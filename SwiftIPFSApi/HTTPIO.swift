//
//  HTTPIO.swift
//  SwiftIPFSApi
//
//  Created by Teo on 21/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//

import Foundation

enum HttpIoError : ErrorType {
    case URLError(String)
    case TransmissionError(String)
}

struct HttpIo : NetworkIo {

    static func receiveFrom(source: String, completionHandler: (NSData) -> Void) throws {
        
    }
    
    static func sendTo(target: String, content: NSData, completionHandler: (NSData) -> Void) throws {
        
    }
    
    static func sendTo(target: String, content: [String], completionHandler: (NSData) -> Void) throws {

        guard let targetUrl = NSURL(string: target) else {
            throw HttpIoError.URLError("Cannot make URL from "+target)
        }

        let lineFeed = "\r\n"
        /// First set up the target connection
        let request     = NSMutableURLRequest(URL: targetUrl)
        
        /// Check if we need to do a multipart post.
//        if content.count > 1 {
        
            let boundary    = Multipart.createBoundary()
            let contentType = "multipart/form-data; boundary=" + boundary
            
            request.HTTPMethod = "POST"
            request.setValue(contentType, forHTTPHeaderField: "content-type")
            request.setValue("Swift IPFS Client", forHTTPHeaderField: "user-agent")

            
            let body        = NSMutableData()
            var outString: String
            /// Then build up the data from the urls
            for source in content {
                
                /** We could add a check here to see if the string is
                    to a local file. Eg. if missing a :// prefix, check if the
                    file exists locally (using NSFileManager fileExistsAtPath)
                    and prepend file:// to it. For now assume the user has added 
                    the necessary prefix...Hahahaha. */
                
                guard let sourceUrl = NSURL(string: source) else {
                    throw HttpIoError.URLError("Cannot make URL from "+source)
                }
                guard let fData = NSData(contentsOfURL: sourceUrl) else { continue }
                
                
                
                outString = "--" + boundary + lineFeed
                body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
                
                if let fileName = sourceUrl.lastPathComponent {
                    outString = "content-disposition: file; name=file; filename=\(fileName)" + lineFeed
                } else {
                    outString = "content-disposition: file; name=file;" + lineFeed
                }
                body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
                
                outString = "content-type: application/octet-stream" + lineFeed
                body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
                
                outString = "content-transfer-encoding: binary" + lineFeed + lineFeed
                body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)
                
                /// Add the actual data for this file.
                body.appendData(fData)
                body.appendData(lineFeed.dataUsingEncoding(NSUTF8StringEncoding)!)
            }
            
            
            /// Finish the body
            outString = "--" + boundary + "--" + lineFeed
            body.appendData(outString.dataUsingEncoding(NSUTF8StringEncoding)!)

            request.setValue(String(body.length), forHTTPHeaderField: "content-length")
            request.HTTPBody = body
        
        
//        } else {
//            
//        }
        
        /// Send off the request
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            
            if error != nil {
                print("arse")//throw HttpIoError.TransmissionError("fail: \(error)")
            } else {
                completionHandler(data!)
            }
        }
        
        task.resume()
    }
    
}

//public func getMIMETypeFromURL(location: NSURL) -> String? {
//    /// is this a file?
//    if  location.fileURL,
//        let fileExtension: CFStringRef = location.pathExtension,
//        let exportedUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, nil)?.takeRetainedValue(),
//        let mimeType = UTTypeCopyPreferredTagWithClass(exportedUTI, kUTTagClassMIMEType) {
//        
//        
//        return mimeType.takeUnretainedValue() as String
//    }
//    return nil
//}
