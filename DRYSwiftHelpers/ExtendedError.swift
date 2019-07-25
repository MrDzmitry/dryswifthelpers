//
// Created by Yuri Drozdovsky on 2019-01-24.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public class ExtendedError: Error, CustomStringConvertible {
    public fileprivate(set) var log = [String]()

    public init() {
    }

    public var description: String {
        get {
            //return String(describing: id)
            var result = ""
            for s in log {
                result.append(s)
                if result.last != "\n" {
                    result.append("\n")
                }
            }
            return result
        }
    }
}

public func check<T>(_ routine: @autoclosure () throws -> T, file: String = #file, line: UInt = #line, column: UInt = #column) throws -> T {
    do {
        return try routine()
    } catch {
        if let extendedError = error as? ExtendedError {
            let fileName = URL(fileURLWithPath: file, isDirectory: false).lastPathComponent
            extendedError.log.insert("\(fileName):\(line):\(column)", at: 0)
            throw error
        } else {
            let extendedError = ExtendedError()
            let fileName = URL(fileURLWithPath: file, isDirectory: false).lastPathComponent
            extendedError.log.append("\(fileName):\(line):\(column) \(String(describing: error)))")
            throw extendedError
        }
    }
}