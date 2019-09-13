//
// Created by Yuri Drozdovsky on 2019-07-25.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public struct WeakBox<A: AnyObject>: Hashable {
    public private(set) weak var value: A?
    private let pointer: UnsafeMutableRawPointer
    public init(_ value: A) {
        self.value = value
        pointer = Unmanaged.passUnretained(value).toOpaque()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pointer)
    }

    public static func ==(lhs: WeakBox<A>, rhs: WeakBox<A>) -> Bool {
        return lhs.hashValue == rhs.hashValue
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

public class Lock {
    private var mutex = pthread_mutex_t()

    public init() {
        let status = pthread_mutex_init(&mutex, nil)
        assert(status == 0)
    }

    deinit {
        let status = pthread_mutex_destroy(&mutex)
        assert(status == 0)
    }

    public func tryLock() -> Bool {
        return pthread_mutex_trylock(&mutex) == 0
    }

    public func lock() {
        let status = pthread_mutex_lock(&mutex)
        assert(status == 0)
    }

    public func unlock() {
        let status = pthread_mutex_unlock(&mutex)
        assert(status == 0)
    }

    @discardableResult
    public func synchronized<T>(_ job: () throws -> T) rethrows -> T {
        lock()
        defer {
            unlock()
        }
        return try job()
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

public struct Atomic<T> {
    private var _value: T
    private let lock = ReadWriteLock()

    public init(_ value: T) {
        _value = value
    }

    public func getValue() -> T {
        return lock.withReadLock {
            return _value
        }
    }

    public mutating func setValue(_ newValue: T) {
        lock.withWriteLock {
            _value = newValue
        }
    }

    public func withReadLock<R>(_ job: (T) -> R) -> R {
        return lock.withReadLock {
            job(_value)
        }
    }

    public mutating func withWriteLock<R>(_ job: (inout T) -> R) -> R {
        return lock.withWriteLock {
            job(&_value)
        }
    }
}

extension Atomic where T: Equatable {
    public mutating func compareAndSet(_ newValue: T) -> Bool {
        let didSet = lock.withWriteLock { () -> Bool in
            if _value != newValue {
                _value = newValue
                return true
            } else {
                return false
            }
        }
        return didSet
    }
}

public class Condition<T: Equatable> {
    private var value: Atomic<T>
    private let valueChangedEvent = Event<T>()

    public init(_ value: T) {
        self.value = Atomic(value)
    }

    public func waitForValue(_ expectedValue: T) {
        let semaphore = Semaphore()
        var eventHandler: EventHandler?

        let shouldWait = value.withReadLock { (currentValue) -> Bool in
            if currentValue == expectedValue {
                return false
            } else {
                eventHandler = valueChangedEvent.addHandler { newValue in
                    if newValue == expectedValue {
                        semaphore.signal()
                    }
                }
                return true
            }
        }

        if shouldWait {
            semaphore.wait()
            eventHandler?.dispose()
        }
    }

    public func setValue(_ newValue: T) {
        value.setValue(newValue)
        valueChangedEvent.raise(newValue)
    }
}
