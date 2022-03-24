//
//  File 2.swift
//  
//
//  Created by Monterey on 23/3/22.
//

import Foundation
import SwiftFormat
import SwiftFormatConfiguration

func prettify(text: String) -> String {
    var configuration = Configuration()
    configuration.indentation = .spaces(4)
        
    let formatter = SwiftFormatter(configuration: configuration)
    var result = ""
    do {
        try formatter.format(source: text, assumingFileURL: nil, to: &result)
        return result
    } catch {
        fatalError("Trying to prettify: \(text), cannot format text: \(error)")
    }
}
