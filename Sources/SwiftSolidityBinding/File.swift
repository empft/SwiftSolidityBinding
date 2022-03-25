//
//  File.swift
//  
//
//  Created by Monterey on 23/3/22.
//
import Foundation

struct File {
    static func parseJson<T: Decodable>(
        fileURL: URL,
        jsonType: T.Type
    ) -> T {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
            
        } catch {
            fatalError("Cannot read input abi: \(error)")
        }
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(jsonType, from: data)
        } catch {
            fatalError("Cannot decode json, inputFile: \(fileURL): \(error)")
        }
    }
    
    static func generate(
        fileURL: URL,
        content: String
    ) {
        do {
            let manager = FileManager.default
            
            if !manager.fileExists(atPath: fileURL.path) {
                try manager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            fatalError("Cannot write to file: \(error)")
        }
    }
}


