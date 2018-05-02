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

enum HttpIoError : Error {
    case urlError(String)
    case transmissionError(String)
}

public struct HttpIo : NetworkIo {

    public func receiveFrom(_ source: String, completionHandler: @escaping (Data) throws -> Void) throws {
        guard let url = URL(string: source) else { throw HttpIoError.urlError("Invalid URL") }
        print("HttpIo receiveFrom url is \(url)")
        let task = URLSession.shared.dataTask(with: url) {
            (data: Data?, response: URLResponse?, error: Error?) in
            
            do {
                guard error == nil else { throw HttpIoError.transmissionError((error?.localizedDescription)!) }
                guard let data = data else { throw IpfsApiError.nilData }
                
//                print("The data:",NSString(data: data, encoding: String.Encoding.utf8.rawValue))
                
                try completionHandler(data)
                
            } catch {
                print("Error ", error, "in completionHandler passed to fetchData ")
            }
        }
        
        task.resume()
    }
   
    
    public func streamFrom( _ source: String,
                            updateHandler: @escaping (Data, URLSessionDataTask) throws -> Bool,
                            completionHandler: @escaping (AnyObject) throws -> Void) throws {
    
        guard let url = URL(string: source) else { throw HttpIoError.urlError("Invalid URL") }
        let config = URLSessionConfiguration.default
        let handler = StreamHandler(updateHandler: updateHandler, completionHandler: completionHandler)
        let session = URLSession(configuration: config, delegate: handler, delegateQueue: nil)
        let task = session.dataTask(with: url)
        
        task.resume()
    }
    
    public func sendTo(_ target: String, content: Data, completionHandler: @escaping (Data) -> Void) throws {

        var multipart = try Multipart(targetUrl: target, encoding: .utf8)
        multipart = try Multipart.addFilePart(multipart, fileName: nil , fileData: content)
        Multipart.finishMultipart(multipart, completionHandler: completionHandler)
    }


    public func sendTo(_ target: String, filePath: String, completionHandler: @escaping (Data) -> Void) throws {
        
        var multipart = try Multipart(targetUrl: target, encoding: .utf8)
        
        multipart = try handle(oldMultipart: multipart, files: [filePath])
        
        Multipart.finishMultipart(multipart, completionHandler: completionHandler)
        
    }
    
    func handle(oldMultipart: Multipart, files: [String], prePath: String? = nil) throws -> Multipart{
        
        var multipart = oldMultipart
        let filemgr = FileManager.default
        var isDir : ObjCBool = false

        for file in files {
            
            let path = NSString(string: file).replacingOccurrences(of: "file://", with: "")
            let prePath = prePath ?? (path as NSString).deletingLastPathComponent + "/"
            guard filemgr.fileExists(atPath: path, isDirectory: &isDir) else { throw HttpIoError.urlError("file not found at given path: \(path)") }
            
            if isDir.boolValue == true {
                
                let trimmedPath = path.replacingOccurrences(of: prePath, with: "")
                
                /// Expand directory and call recursively with the contents.
                multipart = try Multipart.addDirectoryPart(oldMultipart: multipart, path: trimmedPath)
                
                let dirFiles = try filemgr.contentsOfDirectory(atPath: path)
                
                let newPaths = dirFiles.map { aFile in (path as NSString).appendingPathComponent(aFile)}
                
                if dirFiles.count > 0 {
                    multipart = try handle(oldMultipart: multipart, files: newPaths, prePath: prePath)
                }
                
            } else {
                
                /// Add the contents of the file to multipart message.
                let fileUrl = URL(fileURLWithPath: path)
                guard let fileData = try? Data(contentsOf: fileUrl) else { throw MultipartError.failedURLCreation }
                let trimmedFilePath = path.replacingOccurrences(of: prePath, with: "")
                
                multipart = try Multipart.addFilePart(multipart, fileName: trimmedFilePath, fileData: fileData)
            }
        }
        
        return multipart
    }
    
    func fetchUpdateHandler(_ data: Data, task: URLSessionDataTask) {
        
        /// At this point we could decide to stop the task.
        if task.countOfBytesReceived > 1024 {
            print("fetch task cancel")
            task.cancel()
        }
    }
    
    func fetchCompletionHandler(_ result: AnyObject) {
        
        for res in result as! [[String : AnyObject]] {
            print(res)
        }
    }
}

public class StreamHandler : NSObject, URLSessionDataDelegate {
    
    var dataStore = NSMutableData()
    let updateHandler: (Data, URLSessionDataTask) throws -> Bool
    let completionHandler: (AnyObject) throws -> Void
    
    init(updateHandler: @escaping (Data, URLSessionDataTask) throws -> Bool, completionHandler: @escaping (AnyObject) throws -> Void) {
        self.updateHandler = updateHandler
        self.completionHandler = completionHandler
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        dataStore.append(data)
        
        do {
            // fire the update handler
            // FIX: Use the return value of the update handler to signal that we want to end the stream.
            try _ = updateHandler(data, dataTask)
        } catch {
            print("In StreamHandler: updateHandler error: \(error)")
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        session.invalidateAndCancel()
        do {
            try completionHandler(dataStore)
        } catch {
            print("In StreamHandler: completionHandler error: \(error)")
        }
    }
}
