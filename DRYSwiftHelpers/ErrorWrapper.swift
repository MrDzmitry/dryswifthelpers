//
// Created by Yuri Drozdovsky on 2019-01-24.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public class ErrorWrapper: Error, LocalizedError {
    fileprivate(set) var log = [String]()
    var innerError: Error

    public init(innerError: Error) {
        self.innerError = innerError
    }

    public var errorDescription: String? {
        get {
            return innerError.localizedDescription
        }
    }
}

public func wrapError<T>(_ routine: @autoclosure () throws -> T) throws -> T {
    do {
        return try routine()
    } catch {
        if let wrappedError = error as? ErrorWrapper {
            throw wrappedError
        } else {
            let wrappedError = ErrorWrapper(innerError: error)
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
