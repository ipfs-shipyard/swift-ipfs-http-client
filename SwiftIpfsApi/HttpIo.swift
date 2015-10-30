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
    case URLError(String)
    case TransmissionError(String)
}

struct HttpIo : NetworkIo {

    static func receiveFrom(source: String, completionHandler: (NSData) -> Void) throws {
        
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
                throw HttpIoError.URLError("Cannot make URL from "+source)
            }
            guard let fData = NSData(contentsOfURL: sourceUrl) else { continue }
            
            multipart = try Multipart.addFilePart(multipart, fileName: sourceUrl.lastPathComponent , fileData: fData)
        }
        
        Multipart.finishMultipart(multipart, completionHandler: completionHandler)
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
