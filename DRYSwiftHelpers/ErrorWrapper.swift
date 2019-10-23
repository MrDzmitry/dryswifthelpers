//
// Created by Yuri Drozdovsky on 2019-01-24.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public struct ErrorWrapper: Error, CustomStringConvertible, LocalizedError {
    fileprivate(set) var log = [String]()
    var innerError: Error

    init(innerError: Error) {
        self.innerError = innerError
    }

    public var description: String {
        get {
            let result = log.reversed().joined(separator: " -> ")
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
        throw wrapError(error, file: file, line: line, column: column)
    }
}

public func wrapError(_ error: Error, file: String = #file, line: UInt = #line, column: UInt = #column) -> ErrorWrapper {
    if var wrappedError = error as? ErrorWrapper {
        let fileName = URL(fileURLWithPath: file, isDirectory: false).lastPathComponent
        wrappedError.log.append("\(fileName):\(line):\(column)")
        return wrappedError
    } else {
        var wrappedError = ErrorWrapper(innerError: error)
        let fileName = URL(fileURLWithPath: file, isDirectory: false).lastPathComponent
        wrappedError.log.append("\(fileName):\(line):\(column) \(String(describing: error))")
        return wrappedError
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
