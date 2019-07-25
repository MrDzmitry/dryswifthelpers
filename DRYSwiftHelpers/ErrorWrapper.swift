//
// Created by Yuri Drozdovsky on 2019-01-24.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public class ErrorWrapper: Error, LocalizedError {
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
        if let extendedError = error as? ErrorWrapper {
            throw extendedError
        } else {
            let extendedError = ErrorWrapper(innerError: error)
            throw extendedError
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
