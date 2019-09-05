//
// Created by Yuri Drozdovsky on 2019-01-24.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public class ErrorWrapper: Error, CustomStringConvertible, LocalizedError {
    fileprivate(set) var log = [String]()
    var innerError: Error

    public init(innerError: Error) {
        self.innerError = innerError
    }

    public var description: String {
        get {
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

    public var errorDescription: String? {
        get {
            return innerError.localizedDescription
        }
    }
}

@discardableResult
public func wrapError<T>(_ routine: @autoclosure () throws -> T, file: String = #file, line: UInt = #line, column: UInt = #column) throws -> T {
    do {
        return try routine()
    } catch {
        if let wrappedError = error as? ErrorWrapper {
            let fileName = URL(fileURLWithPath: file, isDirectory: false).lastPathComponent
            wrappedError.log.insert("\(fileName):\(line):\(column)", at: 0)
            throw wrappedError
        } else {
            let wrappedError = ErrorWrapper(innerError: error)
            let fileName = URL(fileURLWithPath: file, isDirectory: false).lastPathComponent
            wrappedError.log.append("\(fileName):\(line):\(column) \(String(describing: error)))")
            throw wrappedError
        }
    }
}

extension Error {
    public var unwrappedError: Error {
        get {
            if let wrappedError = self as? ErrorWrapper {
                return wrappedError.innerError
            } else {
                return self
            }
        }
    }
}
