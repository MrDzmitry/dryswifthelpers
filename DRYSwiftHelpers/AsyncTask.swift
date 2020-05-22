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
    func addResultHandler(_ block: @escaping (Result<Any>) -> Void)
}

public protocol CancellableAsyncTask {
    func cancel()
}

public class AsyncTask<T>: AsyncResultProvider, CancellableAsyncTask {
    private var job: (() throws -> T)?
    private let lock = Lock()
    private var onResultBlocks = [(Result<T>) -> Void]()
    private var onCancelBlock: (() -> Void)?
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

    public init() {
    }

    public init(paused: Bool = false, _ job: @escaping () throws -> T) {
        self.job = job
        if paused == false {
            run()
        }
    }

    public func run() {
        lock.synchronized {
            if let job = self.job {
                self.job = nil
                DispatchQueue.global().async {
                    do {
                        let value = try job()
                        self.setResult(.value(value))
                    } catch {
                        self.setResult(.error(error))
                    }
                }
            }
        }
    }

    public func setResult(_ newValue: Result<T>) {
        self.lock.synchronized {
            if result == nil {
                result = newValue

                for onResultBlock in self.onResultBlocks {
                    onResultBlock(newValue)
                }
                self.onResultBlocks.removeAll()

                if let value = newValue.getValue() {
                    for block in self.successBlocks {
                        DispatchQueue.main.async {
                            block(value)
                        }
                    }
                }
                self.successBlocks.removeAll()

                if let error = newValue.getError() {
                    for block in self.catchBlocks {
                        DispatchQueue.main.async {
                            block(error)
                        }
                    }
                }
                self.catchBlocks.removeAll()

                for block in self.finallyBlocks {
                    DispatchQueue.main.async {
                        block()
                    }
                }
                self.finallyBlocks.removeAll()
            }
        }
    }

    public func getResult() -> Result<T>? {
        return self.lock.synchronized {
            return result
        }
    }

    public func addResultHandler(_ block: @escaping (Result<Any>) -> Void) {
        onResult { result in
            switch result {
            case .value(let value):
                block(Result.value(value))
            case .error(let error):
                block(Result.error(error))
            }
        }
    }

    public func onCancel(_ block: @escaping () -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            self.onCancelBlock = block
        }
        return self
    }

    @discardableResult
    public func onResult(_ block: @escaping (Result<T>) -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            if let result = self.result {
                block(result)
            } else {
                self.onResultBlocks.append(block)
            }
        }
        return self
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
        self.addResultHandler { result in
            semaphore.signal()
        }
        self.run()
        do {
            try semaphore.wait(timeout: timeout)
        } catch {
            throw DRYSwiftHelpersError.asyncTaskTimedOut
        }

        switch self.result! {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }

    public func cancel() {
        self.lock.synchronized {
            if self.result == nil {
                self.onCancelBlock?()
            }
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
    let results = Atomic(Array<Result<Any>?>(repeating: nil, count: tasks.count))
    var firstError: Error?
    var resultsCount = 0
    for i in 0..<tasks.count {
        let task = tasks[i]
        task.addResultHandler { result in
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
