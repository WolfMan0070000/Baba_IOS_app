//
//  Array+Chunked.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import Foundation

extension Array {
    /// Split array into chunks of specified size
    /// - Parameter size: Maximum size of each chunk
    /// - Returns: Array of chunks
    func chunkedInto(_ size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        
        return stride(from: 0, to: count, by: size).map {
            let startIndex = $0
            let endIndex = Swift.min($0 + size, count)
            return Array(self[startIndex..<endIndex])
        }
    }
}