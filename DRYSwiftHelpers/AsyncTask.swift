//
// Created by Yuri Drozdovsky on 2019-01-23.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Dispatch

public enum Result<T> {
    case value(T)
    case error(Error)
}

public class AsyncContext {
    private var semaphore = DispatchSemaphore(value: 0)

    func suspend() {
        _ = semaphore.wait(timeout: .distantFuture)
    }

    func suspend(timeout: DispatchTime) throws {
        if semaphore.wait(timeout: timeout) == .timedOut {
            throw DRYSwiftHelpersError.asyncTaskTimeout
        }
    }

    func resume() {
        semaphore.signal()
    }

/*
    public func sleep(forTimeInterval timeInterval: TimeInterval) {
        Thread.sleep(forTimeInterval: timeInterval)
    }
*/

    @discardableResult
    public func await<T>(task: AsyncTask<T>, timeout: DispatchTime = .distantFuture) throws -> T {
        task.onResult { result in
            self.resume()
        }
        task.run(asyncContext: self)
        try suspend(timeout: timeout)

        switch task.result.value! {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }

    @discardableResult
    public func await(tasks: [AsyncResultProvider], timeout: DispatchTime = .distantFuture, throwFirstError: Bool = false) throws -> [Result<Any>] {
        var results = Atomic([Result<Any>]())
        var firstError: Error?
        for task in tasks {
            task.onResult { result in
                var resume = false
                results.synchronized { results in
                    results.append(result)
                    if results.count == tasks.count {
                        resume = true
                    } else if throwFirstError == true, case let Result.error(error) = result {
                        if firstError == nil {
                            firstError = error
                        }
                        resume = true
                    }
                    if resume == true {
                        self.resume()
                    }
                }
            }
            DispatchQueue.global().async {
                task.run(asyncContext: AsyncContext())
            }
        }
        try suspend(timeout: timeout)
        if firstError != nil {
            throw firstError!
        }
        return results.value
    }
}

public protocol AsyncResultProvider {
    func run(asyncContext: AsyncContext)
    func onResult(_ block: @escaping (Result<Any>) -> Void)
}

public class AsyncTask<T>: AsyncResultProvider {
    private var job: ((AsyncContext) throws -> T)
    private var onResultBlocks = [(Result<Any>) -> Void]()
    fileprivate let dispatchGroup = DispatchGroup()
    public private(set) var result = Atomic<Result<T>?>(nil)

    public var resultValue: T? {
        if let result = self.result.value, case Result<T>.value(let value) = result {
            return value
        } else {
            return nil
        }
    }

    public var resultError: Error? {
        if let result = self.result.value, case Result<T>.error(let error) = result {
            return error
        } else {
            return nil
        }
    }

    public init(_ job: @escaping (AsyncContext) throws -> T) {
        self.job = job
    }

    public func run(asyncContext: AsyncContext) {
        do {
            let value = try self.job(AsyncContext())
            self.result.synchronized { result in
                if result == nil {
                    result = .value(value)
                    for completionBlock in self.onResultBlocks {
                        completionBlock(.value(value))
                    }
                }
            }
        } catch {
            self.result.synchronized { result in
                if result == nil {
                    result = .error(error)
                    for onResultBlock in self.onResultBlocks {
                        onResultBlock(.error(error))
                    }
                }
            }
        }
    }

    public func onResult(_ block: @escaping (Result<Any>) -> Void) {
        self.result.synchronized { result in
            self.onResultBlocks.append(block)
            if let result = result {
                switch result {
                case .value(let value):
                    block(Result.value(value))
                case .error(let error):
                    block(Result.error(error))
                }
            }
        }
    }
}

public class AsyncTaskRunner<T> {
    private var job: ((AsyncContext) throws -> T)
    fileprivate let dispatchGroup = DispatchGroup()
    private var catchBlocks = [(Error) -> Void]()
    private var successBlocks = [(T) -> Void]()
    private var finallyBlocks = [() -> Void]()
    public private(set) var result = Atomic<Result<T>?>(nil)

    public init(_ job: @escaping (AsyncContext) throws -> T) {
        self.job = job
    }

    @discardableResult
    public func onSuccess(_ block: @escaping (T) -> Void) -> AsyncTaskRunner<T> {
        self.result.synchronized { result in
            self.successBlocks.append(block)
            if case let Result.value(value)? = result {
                block(value)
            }
        }
        return self
    }

    @discardableResult
    public func onError(_ block: @escaping (Error) -> Void) -> AsyncTaskRunner<T> {
        self.result.synchronized { result in
            self.catchBlocks.append(block)
            if case let Result.error(error)? = result {
                block(error)
            }
        }
        return self
    }

    @discardableResult
    public func finally(_ block: @escaping () -> Void) -> AsyncTaskRunner<T> {
        self.result.synchronized { result in
            self.finallyBlocks.append(block)
            if result != nil {
                block()
            }
        }
        return self
    }

    func run() {
        DispatchQueue.global().async(group: dispatchGroup) {
            do {
                let value = try self.job(AsyncContext())
                self.result.value = .value(value)
                let successBlocks = self.successBlocks
                let finallyBlocks = self.finallyBlocks
                if successBlocks.count > 0 || finallyBlocks.count > 0 {
                    DispatchQueue.main.async(group: self.dispatchGroup) {
                        for block in successBlocks {
                            block(value)
                        }
                        for block in finallyBlocks {
                            block()
                        }
                    }
                }
            } catch {
                self.result.value = .error(error)
                let catchBlocks = self.catchBlocks
                let finallyBlocks = self.finallyBlocks
                if catchBlocks.count > 0 || finallyBlocks.count > 0 {
                    DispatchQueue.main.async(group: self.dispatchGroup) {
                        for block in self.catchBlocks {
                            block(error)
                        }
                        for block in self.finallyBlocks {
                            block()
                        }
                    }
                }
            }
        }
    }
}

@discardableResult
public func async<T>(_ job: @escaping (AsyncContext) throws -> T) -> AsyncTaskRunner<T> {
    let taskRunner = AsyncTaskRunner(job)
    taskRunner.run()
    return taskRunner
}