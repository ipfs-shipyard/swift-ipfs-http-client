//
//  Multipart.swift
//  SwiftIpfsApi
//
//  Created by Matteo Sartori on 20/10/15.
//  Copyright © 2015 Teo Sartori. All rights reserved.
//
//  Licensed under MIT See LICENCE file in the root of this project for details. 

import Foundation

public enum MultipartError : Error {
    case failedURLCreation
    case invalidEncoding
    case dataEmpty
}

public struct Multipart {
    
    static let lineFeed:String = "\r\n"
    let boundary: String
    let encoding: String.Encoding
    let charset: String
    var body = NSMutableData()
    let request: NSMutableURLRequest

    init(targetUrl: String, encoding: String.Encoding) throws {
        
        // Eg. UTF8
        self.encoding = encoding
        guard let charset = Multipart.charsetString(from: encoding) else { throw MultipartError.invalidEncoding }
        
        self.charset = charset

        boundary = Multipart.createBoundary()

        guard let url = URL(string: targetUrl) else { throw MultipartError.failedURLCreation }
        request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary="+boundary, forHTTPHeaderField: "content-type")
        request.setValue("Swift IPFS Client", forHTTPHeaderField: "user-agent")
    }
}

extension Multipart {

    static func charsetString(from encoding: String.Encoding) -> String? {
        switch encoding {
        case String.Encoding.utf8:
            return "UTF8"
        case String.Encoding.ascii:
            return "ASCII"
        default:
            return nil
        }
    }

    /// Generate a string of 32 random alphanumeric characters.
    static func createBoundary() -> String {
    
        let allowed     = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let count       = 32
        var output      = ""
        
        for _ in 0 ..< count {
            let randomCharacter = allowed.randomElement()
            assert(randomCharacter != nil)

			output += String(randomCharacter ?? Character(""))
        }
        
        return output
    }
    
    static func addFormField(oldMultipart: Multipart, name: String, value: String) throws -> Multipart {
        
        let encoding = oldMultipart.encoding
        
        var outString = "--" + oldMultipart.boundary + lineFeed
        oldMultipart.body.append(outString.data(using: encoding)!)
        
        outString = "content-disposition: form-data; name=\"" + name + "\"" + lineFeed
        oldMultipart.body.append(outString.data(using: encoding)!)
        
        outString = "content-type: text/plain; charset=\"" + oldMultipart.charset + "\"" + lineFeed
        oldMultipart.body.append(outString.data(using: encoding)!)
        
        oldMultipart.body.append(lineFeed.data(using: encoding)!)
        
        oldMultipart.body.append(value.data(using: encoding)!)
        oldMultipart.body.append(lineFeed.data(using: encoding)!)
        
        return oldMultipart
    }

    static func addDirectoryPart(oldMultipart: Multipart, path: String) throws -> Multipart {
        
        let encoding = oldMultipart.encoding
        
        var outString = "--" + oldMultipart.boundary + lineFeed
        oldMultipart.body.append(outString.data(using: encoding)!)
        
        outString = "content-disposition: file; filename=\"\(path)\"" + lineFeed
        oldMultipart.body.append(outString.data(using: encoding)!)

        outString = "content-type: application/x-directory" + lineFeed
        oldMultipart.body.append(outString.data(using: encoding)!)
        
        outString = "content-transfer-encoding: binary" + lineFeed
        oldMultipart.body.append(outString.data(using: encoding)!)
        
        oldMultipart.body.append(lineFeed.data(using: encoding)!)
        oldMultipart.body.append(lineFeed.data(using: encoding)!)
        
        return oldMultipart
    }
    
    public static func addFilePart(_ oldMultipart: Multipart, fileName: String?, fileData: Data) throws -> Multipart {
        
        var outString = "--" + oldMultipart.boundary + lineFeed
        oldMultipart.body.append(outString.data(using: .utf8)!)

        if fileName != nil {
            outString = "content-disposition: file; filename=\"\(fileName!)\";" + lineFeed
        } else {
            outString = "content-disposition: file; name=\"file\";" + lineFeed
        }
        
        oldMultipart.body.append(outString.data(using: .utf8)!)
        
        outString = "content-type: application/octet-stream" + lineFeed
        oldMultipart.body.append(outString.data(using: .utf8)!)
        
        outString = "content-transfer-encoding: binary" + lineFeed + lineFeed
        oldMultipart.body.append(outString.data(using: .utf8)!)
        
        /// Add the actual data for this file.
        oldMultipart.body.append(fileData)
        oldMultipart.body.append(lineFeed.data(using: .utf8)!)
        
        return oldMultipart
    }
    
    public static func finishMultipart(_ multipart: Multipart, completionHandler: @escaping (Result<Data, Error>) -> Void) {
        let outString = "--" + multipart.boundary + "--" + lineFeed

        guard let outData = outString.data(using: .utf8) else {
            return completionHandler(.failure(MultipartError.invalidEncoding))
        }
        
        multipart.body.append(outData)
        multipart.request.setValue(String(multipart.body.length), forHTTPHeaderField: "content-length")
        multipart.request.httpBody = multipart.body as Data

        /// Send off the request
        URLSession.shared.dataTask(with: multipart.request as URLRequest) { data, response, error in
            guard let safeData = data else {
                return completionHandler(.failure(MultipartError.dataEmpty))
            }

            if let safeError = error {
                return completionHandler(.failure(safeError))
            }

            completionHandler(.success(safeData))
        }.resume()
    }
}
