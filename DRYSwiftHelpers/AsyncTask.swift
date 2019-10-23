//
// Created by Yuri Drozdovsky on 2019-01-23.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Dispatch

public enum Result<T> {
    case value(T)
    case error(Error)

    public func getValue() -> T? {
        if case .value(let result) = self {
            return result
        } else {
            return nil
        }
    }

    public func getError() -> Error? {
        if case .error(let result) = self {
            return result
        } else {
            return nil
        }
    }

    func asResultAny() -> Result<Any> {
        switch self {
        case .value(let value):
            return Result<Any>.value(value)
        case .error(let error):
            return Result<Any>.error(error)
        }
    }
}

public protocol AsyncResultProvider {
    //func run()
    func onResult(_ block: @escaping (Result<Any>) -> Void)
}

public class AsyncTask<T>: AsyncResultProvider {
    private var job: (() throws -> T)?
    private var didRun = Atomic<Bool>(false)
    private let lock = Lock()
    private var onResultBlocks = [(Result<Any>) -> Void]()
    //fileprivate let dispatchGroup = DispatchGroup()
    private var catchBlocks = [(Error) -> Void]()
    private var successBlocks = [(T) -> Void]()
    private var finallyBlocks = [() -> Void]()
    private var result: Result<T>?

    public var resultValue: T? {
        return lock.synchronized {
            if case Result<T>.value(let value)? = result {
                return value
            } else {
                return nil
            }
        }
    }

    public var resultError: Error? {
        return lock.synchronized {
            if case Result<T>.error(let error)? = result {
                return error
            } else {
                return nil
            }
        }
    }

    public init(paused: Bool = false, _ job: @escaping () throws -> T) {
        self.job = job
        if paused == false {
            run()
        }
    }

    public func run() {
        if didRun.compareAndSet(true) == false {
            return
        }
        DispatchQueue.global().async {
            do {
                let value = try self.job!()
                self.lock.synchronized {
                    if self.result == nil {
                        self.result = .value(value)
                        for onResultBlock in self.onResultBlocks {
                            onResultBlock(.value(value))
                        }
                        self.onResultBlocks.removeAll()

                        for block in self.successBlocks {
                            DispatchQueue.main.async {
                                block(value)
                            }
                        }
                        self.successBlocks.removeAll()
                        self.catchBlocks.removeAll()

                        for block in self.finallyBlocks {
                            DispatchQueue.main.async {
                                block()
                            }
                        }
                        self.finallyBlocks.removeAll()
                    }
                }
            } catch {
                self.lock.synchronized {
                    if self.result == nil {
                        self.result = .error(error)
                        for onResultBlock in self.onResultBlocks {
                            onResultBlock(.error(error))
                        }
                        self.onResultBlocks.removeAll()

                        for block in self.catchBlocks {
                            DispatchQueue.main.async {
                                block(error)
                            }
                        }
                        self.catchBlocks.removeAll()
                        self.successBlocks.removeAll()

                        for block in self.finallyBlocks {
                            DispatchQueue.main.async {
                                block()
                            }
                        }
                        self.finallyBlocks.removeAll()
                    }
                }
            }
            self.job = nil
        }
    }

    public func onResult(_ block: @escaping (Result<Any>) -> Void) {
        self.lock.synchronized {
            if let result = self.result {
                switch result {
                case .value(let value):
                    block(Result.value(value))
                case .error(let error):
                    block(Result.error(error))
                }
            } else {
                self.onResultBlocks.append(block)
            }
        }
    }

    @discardableResult
    public func onSuccess(_ block: @escaping (T) -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            if case let Result.value(value)? = self.result {
                DispatchQueue.main.async {
                    block(value)
                }
            } else {
                self.successBlocks.append(block)
            }
        }
        return self
    }

    @discardableResult
    public func onError(_ block: @escaping (Error) -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            if case let Result.error(error)? = self.result {
                DispatchQueue.main.async {
                    block(error)
                }
            } else {
                self.catchBlocks.append(block)
            }
        }
        return self
    }

    @discardableResult
    public func finally(_ block: @escaping () -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            if self.result != nil {
                DispatchQueue.main.async {
                    block()
                }
            } else {
                self.finallyBlocks.append(block)
            }
        }
        return self
    }

    @discardableResult
    public func await(timeout: DispatchTime = .distantFuture) throws -> T {
        assert(Thread.isMainThread == false)
        let semaphore = Semaphore()
        self.onResult { result in
            semaphore.signal()
        }
        self.run()
        try semaphore.wait(timeout: timeout)

        switch self.result.getValue()! {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }
}

@discardableResult
public func async<T>(_ job: @escaping () throws -> T) -> AsyncTask<T> {
    return AsyncTask<T>(job)
}

/*
@discardableResult
public func await<T>(task: AsyncTask<T>, timeout: DispatchTime = .distantFuture) throws -> T {
    assert(Thread.isMainThread == false)
    return try task.await(timeout: timeout)
}
*/

@discardableResult
public func await(tasks: [AsyncResultProvider], timeout: DispatchTime = .distantFuture, muteErrors: Bool = false) throws -> [Result<Any>?] {
    assert(Thread.isMainThread == false)
    let semaphore = Semaphore()
    var results = Atomic(Array<Result<Any>?>(repeating: nil, count: tasks.count))
    var firstError: Error?
    var resultsCount = 0
    for i in 0..<tasks.count {
        let task = tasks[i]
        task.onResult { result in
            var resume = false
            results.withWriteLock { results in
                results[i] = result
                resultsCount += 1
                if muteErrors == false, case let Result.error(error) = result {
                    if firstError == nil {
                        firstError = error
                    }
                    resume = true
                }
                if resultsCount == results.count {
                    resume = true
                }
                if resume == true {
                    semaphore.signal()
                }
            }
        }
        //task.run()
    }
    try semaphore.wait(timeout: timeout)
    if firstError != nil {
        throw firstError!
    }
    return results.getValue()
}

public class ExternalAsyncTask<T>: AsyncResultProvider {
    private var result: Result<T>?
    private var lock = Lock()
    private var onResultBlocks = [(Result<Any>) -> Void]()

    public init() {}

    public func onResult(_ block: @escaping (Result<Any>) -> Void) {
        self.lock.synchronized {
            if let result = self.result {
                switch result {
                case .value(let value):
                    block(Result.value(value))
                case .error(let error):
                    block(Result.error(error))
                }
            } else {
                self.onResultBlocks.append(block)
            }
        }
    }

    public func setResult(_ newValue: Result<T>?) {
        self.lock.synchronized {
            self.result = newValue
            if let resultAny = result?.asResultAny() {
                for onResultBlock in self.onResultBlocks {
                    onResultBlock(resultAny)
                }
                self.onResultBlocks.removeAll()
            }
        }
    }

    public func getResult() -> Result<T>? {
        return self.lock.synchronized {
            return result
        }
    }

    @discardableResult
    public func await(timeout: DispatchTime = .distantFuture) throws -> T {
        assert(Thread.isMainThread == false)
        let semaphore = Semaphore()
        var resultValue: T?
        var resultError: Error?
        self.onResult { result in
            switch result {
            case .value(let value):
                resultValue = (value as! T)
            case .error(let error):
                resultError = error
            }
            semaphore.signal()
        }
        try semaphore.wait(timeout: timeout)
        if resultError != nil {
            throw resultError!
        }
        return resultValue!
    }
}
