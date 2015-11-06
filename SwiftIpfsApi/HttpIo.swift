//
//  HttpIo.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 21/10/15.
//
//  Copyright © 2015 Matteo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details.

import Foundation

enum HttpIoError : ErrorType {
    case UrlError(String)
    case TransmissionError(String)
}

public struct HttpIo : NetworkIo {

    static func receiveFrom(source: String, completionHandler: (NSData) throws -> Void) throws {
        
        guard let url = NSURL(string: source) else { throw HttpIoError.UrlError("Invalid URL") }
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url) {
            (data: NSData?, response: NSURLResponse?, error: NSError?) in
            
            do {
                guard error == nil else { throw HttpIoError.TransmissionError((error?.localizedDescription)!) }
                guard let data = data else { throw IpfsApiError.NilData }
                
                //print("The data:",NSString(data: data, encoding: NSUTF8StringEncoding))
                
                try completionHandler(data)
                
            } catch {
                print("Error ", error, "in completionHandler passed to fetchData ")
            }
        }
        
        task.resume()
    }
   
    
    func streamFrom(source: String, updateHandler: (NSData, NSURLSessionDataTask) -> Void, completionHandler: (AnyObject) -> Void) throws {
    
        guard let url = NSURL(string: source) else { throw HttpIoError.UrlError("Invalid URL") }
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let handler = StreamHandler(updateHandler: updateHandler, completionHandler: completionHandler)
        let session = NSURLSession(configuration: config, delegate: handler, delegateQueue: nil)
        let task = session.dataTaskWithURL(url)
        
        task.resume()
    }
    
    static func sendTo(target: String, content: NSData, completionHandler: (NSData) -> Void) throws {
        var multipart = try Multipart(targetUrl: target, charset: "UTF8")
        multipart = try Multipart.addFilePart(multipart, fileName: nil , fileData: content)
        Multipart.finishMultipart(multipart, completionHandler: completionHandler)
    }


    static func sendTo(target: String, content: [String], completionHandler: (NSData) -> Void) throws {

        var multipart = try Multipart(targetUrl: target, charset: "UTF8")
        /// Then build up the data from the urls
        for source in content {
            
            /** We could add a check here to see if the string is
            to a local file. Eg. if missing a :// prefix, check if the
            file exists locally (using NSFileManager fileExistsAtPath)
            and prepend file:// to it. For now assume the user has added
            the necessary prefix...Hahahaha. */
            
            guard let sourceUrl = NSURL(string: source) else {
                throw HttpIoError.UrlError("Cannot make URL from "+source)
            }
            guard let fData = NSData(contentsOfURL: sourceUrl) else { continue }
            
            multipart = try Multipart.addFilePart(multipart, fileName: sourceUrl.lastPathComponent , fileData: fData)
        }
        
        Multipart.finishMultipart(multipart, completionHandler: completionHandler)
    }
    
    func fetchUpdateHandler(data: NSData, task: NSURLSessionDataTask) {
        print("fetch update")
        /// At this point we could decide to stop the task.
        if task.countOfBytesReceived > 1024 {
            print("fetch task cancel")
            task.cancel()
        }
    }
    
    func fetchCompletionHandler(result: AnyObject) {
        print("fetch completion:")
        for res in result as! [[String : AnyObject]] {
            print(res)
        }
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

public class StreamHandler : NSObject, NSURLSessionDataDelegate {
    
    var dataStore = NSMutableData()
    let updateHandler: (NSData, NSURLSessionDataTask) -> Void
    let completionHandler: (AnyObject) -> Void
    
    init(updateHandler: (NSData, NSURLSessionDataTask) -> Void, completionHandler: (AnyObject) -> Void) {
        self.updateHandler = updateHandler
        self.completionHandler = completionHandler
    }
    
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) throws {
        print("HANDLER:")
        dataStore.appendData(data)
        
        // fire the update handler
        updateHandler(data, dataTask)
    }
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) throws {
        print("Completed")
        session.invalidateAndCancel()
        completionHandler(dataStore)
    }
}
