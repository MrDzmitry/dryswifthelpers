//
// Created by Yuri Drozdovsky on 2019-01-23.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Dispatch

public class AsyncContext {
    private var semaphore = DispatchSemaphore(value: 0)

    fileprivate init() {
    }

    public func suspend() {
        _ = semaphore.wait(timeout: .distantFuture)
    }

    private func suspend(timeout: DispatchTime) -> Bool {
        let waitResult = semaphore.wait(timeout: timeout)
        return waitResult == .timedOut
    }

    public func resume() {
        semaphore.signal()
    }

    public func sleep(forTimeInterval timeInterval: TimeInterval) {
        Thread.sleep(forTimeInterval: timeInterval)
    }

    @discardableResult
    public func await<T>(task: AsyncTask<T>, timeout: DispatchTime = .distantFuture) throws -> T {
        task.onResult { result in
            self.resume()
        }
        let timedOut = suspend(timeout: timeout)

        if timedOut {
            throw DRYSwiftHelpersError.asyncTaskTimeout
        }

        switch task.result! {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }

    @discardableResult
    public func await(tasks: [AsyncResultProvider], timeout: DispatchTime = .distantFuture, throwFirstError: Bool = false) throws -> [Result<Any>] {
        let results = Atomic([Result<Any>]())
        let firstError = Atomic<Error?>(nil)
        for task in tasks {
            task.onResult { result in
                var resume = false
                results.synchronized { results in
                    results.append(result)
                    if results.count == tasks.count {
                        resume = true
                    } else if throwFirstError == true, case let Result.error(error) = result {
                        firstError.synchronized { firstError in
                            if firstError == nil {
                                firstError = error
                            }
                        }
                        resume = true
                    }
                    if resume == true {
                        self.resume()
                    }
                }
            }
        }
        let timedOut = self.suspend(timeout: timeout)
        if timedOut {
            throw DRYSwiftHelpersError.asyncTaskTimeout
        }
        if let error = firstError.value {
            throw error
        }
        return results.value
    }
}

public protocol AsyncResultProvider {
    func onResult(_ block: @escaping (Result<Any>) -> Void)
}

public enum Result<T> {
    case value(T)
    case error(Error)
}

public class AsyncTask<T>: AsyncResultProvider {
    fileprivate var didRun = false
    private let lock = Lock()
    private var job: ((AsyncContext) throws -> T)
    private var catchBlocks = [(Error) -> Void]()
    private var successBlocks = [(T) -> Void]()
    private var finallyBlocks = [() -> Void]()
    private var completionBlocks = [(Result<Any>) -> Void]()
    fileprivate let dispatchGroup = DispatchGroup()
    public private(set) var result: Result<T>?

    public var resultValue: T? {
        if let result = self.result, case Result<T>.value(let value) = result {
            return value
        } else {
            return nil
        }
    }

    public var resultError: Error? {
        if let result = self.result, case Result<T>.error(let error) = result {
            return error
        } else {
            return nil
        }
    }

    public init(_ job: @escaping (AsyncContext) throws -> T) {
        self.job = job
    }

    @discardableResult
    public func run(_ asyncContext: AsyncContext? = nil) -> AsyncTask<T> {
        self.lock.synchronized {
            if self.didRun {
                fatalError("AsyncTask can run only once.")
            }
            self.didRun = true
        }
        DispatchQueue.global().async(group: dispatchGroup) {
            do {
                let value = try self.job(AsyncContext())
                self.lock.synchronized {
                    if self.result == nil {
                        self.result = .value(value)
                        for completionBlock in self.completionBlocks {
                            completionBlock(Result.value(value))
                        }
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
                    }
                }
            } catch {
                self.lock.synchronized {
                    if self.result == nil {
                        self.result = .error(error)
                        for completionBlock in self.completionBlocks {
                            completionBlock(Result.error(error))
                        }
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
        return self
    }

    @discardableResult
    public func onSuccess(_ block: @escaping (T) -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            self.successBlocks.append(block)
            if case let Result.value(value)? = self.result {
                block(value)
            }
        }
        return self
    }

    @discardableResult
    public func `catch`(_ block: @escaping (Error) -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            self.catchBlocks.append(block)
            if case let Result.error(error)? = self.result {
                block(error)
            }
        }
        return self
    }

    @discardableResult
    public func finally(_ block: @escaping () -> Void) -> AsyncTask<T> {
        self.lock.synchronized {
            self.finallyBlocks.append(block)
            if self.result != nil {
                block()
            }
        }
        return self
    }

    public func onResult(_ block: @escaping (Result<Any>) -> Void) {
        self.lock.synchronized {
            self.completionBlocks.append(block)
            if let result = self.result {
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

@discardableResult
public func async<T>(_ job: @escaping (AsyncContext) throws -> T) -> AsyncTask<T> {
    let task = AsyncTask(job)
    task.run()
    return task
}