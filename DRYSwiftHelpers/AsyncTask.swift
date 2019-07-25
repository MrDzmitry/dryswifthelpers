//
// Created by Yuri Drozdovsky on 2019-01-23.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Dispatch

public protocol AsyncContext {
    func suspend()
    func resume()
    func sleep(forTimeInterval timeInterval: TimeInterval)
}

public class AsyncTask<T>: AsyncContext {
    private enum Result {
        case value(T)
        case error(Error)
    }

    private var didRun = false
    private let lock = Lock()
    private var job: ((AsyncContext) throws -> T)
    private var catchBlocks = [(Error) -> Void]()
    private var successBlocks = [(T) -> Void]()
    private var finallyBlocks = [() -> Void]()
    private let dispatchGroup = DispatchGroup()
    private var semaphore = DispatchSemaphore(value: 0)
    private var result: Result?

    public init(_ job: @escaping (AsyncContext) throws -> T) {
        self.job = job
    }

/*
    @discardableResult
    static func run<U>(_ job: @escaping (Task<U>) throws -> U) -> Task<U> {
        let task = Task<U>(job)
        return task.run()
    }
*/

    @discardableResult
    public func run() -> AsyncTask<T> {
        self.lock.synchronized {
            if self.didRun {
                fatalError("AsyncTask can run only once.")
            }
            self.didRun = true
        }
        DispatchQueue.global().async(group: dispatchGroup) {
            do {
                let value = try self.job(self)
                DispatchQueue.main.async(group: self.dispatchGroup) {
                    self.lock.synchronized {
                        self.result = .value(value)
                        for block in self.successBlocks {
                            block(value)
                        }
                        for block in self.finallyBlocks {
                            block()
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async(group: self.dispatchGroup) {
                    self.lock.synchronized {
                        self.result = .error(error)
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

    public func suspend() {
        _ = semaphore.wait(timeout: .distantFuture)
    }

    public func resume() {
        semaphore.signal()
    }

    public func sleep(forTimeInterval timeInterval: TimeInterval) {
        Thread.sleep(forTimeInterval: timeInterval)
    }

    public func wait() throws -> T {
        assert(Thread.isMainThread == false)
        dispatchGroup.wait()
        switch result! {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }
}

@discardableResult
public func async<T>(_ job: @escaping (AsyncContext) throws -> T) -> AsyncTask<T> {
    let task = AsyncTask(job)
    task.run()
    return task
}
