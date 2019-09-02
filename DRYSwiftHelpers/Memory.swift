//
// Created by Yuri Drozdovsky on 2019-07-25.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public struct WeakBox<A: AnyObject> {
    public weak var value: A?
    public init(_ value: A) {
        self.value = value
    }
}

public struct UnownedBox<A: AnyObject>: Hashable {
    public unowned let value: A
    private let pointer: UnsafeMutableRawPointer
    public init(_ value: A) {
        self.value = value
        pointer = Unmanaged.passUnretained(value).toOpaque()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pointer)
    }

    public static func ==(lhs: UnownedBox<A>, rhs: UnownedBox<A>) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

public struct Atomic<T> {
    private var _value: T
    private let lock = DispatchSemaphore(value: 1)
    public var value: T {
        get {
            lock.wait()
            defer {
                lock.signal()
            }
            return _value
        }
        set {
            lock.wait()
            defer {
                lock.signal()
            }
            _value = newValue
        }
    }

    public init(_ value: T) {
        _value = value
    }

    public mutating func synchronized<R>(_ job: (inout T) -> R) -> R {
        lock.wait()
        defer {
            lock.signal()
        }
        return job(&_value)
    }
}

public class Lock {
    private var mutex = pthread_mutex_t()

    public init() {
        pthread_mutex_init(&mutex, nil)
    }

    public func tryLock() -> Bool {
        return pthread_mutex_trylock(&mutex) == 0
    }

    public func lock() {
        pthread_mutex_lock(&mutex)
    }

    public func unlock() {
        pthread_mutex_unlock(&mutex)
    }

    public func synchronized(_ job: () throws -> Void) rethrows {
        lock()
        defer {
            unlock()
        }
        try job()
    }
}

public class ReadWriteLock {
    private var lock = pthread_rwlock_t()

    public init() {
        let status = pthread_rwlock_init(&lock, nil)
        assert(status == 0)
    }

    deinit {
        let status = pthread_rwlock_destroy(&lock)
        assert(status == 0)
    }

    @discardableResult
    public func withReadLock<T>(_ job: () throws -> T) rethrows -> T {
        defer {
            pthread_rwlock_unlock(&lock)
        }
        pthread_rwlock_rdlock(&lock)
        return try job()
    }

    @discardableResult
    public func withWriteLock<T>(_ job: () throws -> T) rethrows -> T {
        defer {
            pthread_rwlock_unlock(&lock)
        }
        pthread_rwlock_wrlock(&lock)
        return try job()
    }
}

public class Semaphore {
    private let semaphore: DispatchSemaphore

    public init() {
        semaphore = DispatchSemaphore(value: 0)
    }

    public func wait() {
        _ = semaphore.wait()
    }

    public func wait(timeout: DispatchTime) throws {
        if semaphore.wait(timeout: timeout) == .timedOut {
            throw DRYSwiftHelpersError.semaphoreTimedOut
        }
    }

    public func signal() {
        _ = semaphore.signal()
    }
}