//
//  GMMIOUtility.swift
//  DiscontinuityMeshGenerator
//
//  Ported by Steve Wainwright on 18/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation

class GMMIOUtility: NSObject {

    class func readFileContents(fileURL: URL) -> (lines: [String]?, error: NSError?) {
        var fileLines:[String]?
        let filemgr = FileManager.default
        var Error: NSError?
        
        // Check if the file already exists
        if filemgr.fileExists(atPath: fileURL.path) {
            var content: String?
            do {
                content = try String(contentsOfFile: fileURL.path, encoding: String.Encoding.utf8)
//                print("Read the txt ok!")
            }
            catch let error as NSError {
                print("\(String(describing: error.localizedFailureReason))")
                do {
                    content = try String(contentsOfFile: fileURL.path, encoding: String.Encoding.utf16)
//                    print("Read the txt ok!")
                }
                catch let error as NSError {
                    print("\(String(describing: error.localizedFailureReason))")
                    do {
                        content = try String(contentsOfFile: fileURL.path, encoding: String.Encoding.isoLatin1)
//                        print("Read the txt ok!")
                    }
                    catch let error as NSError {
                        print("An exception occurred: \(error.domain)")
                        print("Here are some details: \(String(describing: error.localizedFailureReason))")
                        Error = NSError(domain: error.domain, code: error.code, userInfo: error.userInfo)
                    }
                }
            }
            
            if Error == nil,
               let _content = content {
                
                if let _  = _content.firstIndex(of: "\r\n") {
                    fileLines = _content.components(separatedBy: "\r\n") as [String]
                    //print(index) // Index(_compoundOffset: 4, _cache: Swift.String.Index._Cache.character(1))
                }
                else {
                    if let _ = _content.firstIndex(of: "\n") {
                        fileLines = _content.components(separatedBy: "\n") as [String]
                    }
                    else if let _ = _content.firstIndex(of: "\r") {
                        fileLines = _content.components(separatedBy: "\r") as [String]
                    }
                    else {
                        Error = NSError(domain: Bundle.main.bundleIdentifier!, code: 222, userInfo: [NSLocalizedDescriptionKey: "Parser Exception: No lines"])
                    }
                }
            }
        }
        return (fileLines, Error)
    }
    
    class func writeFile(_ outputString: String, fileURL: URL) -> (status: Bool, error: String) {
        var OK: Bool = false
        var errorMessage: String
        do {
            // Write to the file
            try outputString.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            errorMessage = NSLocalizedString("\(fileURL.absoluteString)\n has been successfully exported to apps Documents/Export folder.", comment: "")
            OK = true
        }
        catch let error as NSError {
            print("Failed writing to URL: \(String(describing: fileURL)), Error: " + error.localizedDescription)
            errorMessage = NSLocalizedString("\(fileURL.absoluteString)\n could not be exported to apps Documents/Export folder.", comment: "")
        }
        
        return (OK, errorMessage)
    }
    
    class func trimDownArray(_ items: inout [String]) {
        let indexes = items.indices.filter({ !items[$0].isEmpty })
        if !(indexes.isEmpty) && indexes.count != items.count {
            var itemsCopy: [String] = [] /* capacity: indexes?.count */
            
            indexes.forEach { index in
                itemsCopy.append(items[index])
            }
            items.removeAll()
            for i in 0..<itemsCopy.count {
                items.append(itemsCopy[i])
            }
        }
    }
    
}
