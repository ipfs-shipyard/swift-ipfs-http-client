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

    public func receiveFrom(_ source: String, completionHandler: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: source) else {
            return completionHandler(.failure(HttpIoError.urlError("Invalid URL")))
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let safeError = error {
                return completionHandler(.failure(safeError))
            }

            guard let safeData = data else {
                return completionHandler(.failure(IpfsApiError.nilData))
            }

            return completionHandler(.success(safeData))
        }.resume()
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
    
    public func sendTo(_ target: String, content: Data, completionHandler: @escaping (Result<Data, Error>) -> Void) {
        do {
            var multipart = try Multipart(targetUrl: target, encoding: .utf8)
            multipart = try Multipart.addFilePart(multipart, fileName: nil , fileData: content)

            Multipart.finishMultipart(multipart, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }

    public func sendTo(_ target: String, filePath: String, completionHandler: @escaping (Result<Data, Error>) -> Void) {
        do {
            var multipart = try Multipart(targetUrl: target, encoding: .utf8)
            multipart = try handle(oldMultipart: multipart, files: [filePath])

            Multipart.finishMultipart(multipart, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    func handle(oldMultipart: Multipart, files: [String], prePath: String? = nil) throws -> Multipart{
        
        var multipart = oldMultipart
        let filemgr = FileManager.default
        var isDir : ObjCBool = false

        for file in files {
            
            let path = NSString(string: file).replacingOccurrences(of: "file://", with: "")
            let prePath = prePath ?? (path as NSString).deletingLastPathComponent + "/"
            guard filemgr.fileExists(atPath: path, isDirectory: &isDir) else { throw HttpIoError.urlError("file not found at given path: \(path)") }
            
            if isDir.boolValue {
                
                let trimmedPath = path.replacingOccurrences(of: prePath, with: "")
                
                /// Expand directory and call recursively with the contents.
                multipart = try Multipart.addDirectoryPart(oldMultipart: multipart, path: trimmedPath)
                
                let dirFiles = try filemgr.contentsOfDirectory(atPath: path)
                
                let newPaths = dirFiles.map { aFile in (path as NSString).appendingPathComponent(aFile)}

                guard !dirFiles.isEmpty else {
                    return multipart
                }

                multipart = try handle(oldMultipart: multipart, files: newPaths, prePath: prePath)
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
