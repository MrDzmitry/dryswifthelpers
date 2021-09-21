//
// Created by Yuri Drozdovsky on 2019-08-01.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//
// Based on https://blog.scottlogic.com/2015/02/05/swift-events.html
//

public protocol EventHandler: AnyObject {
    @discardableResult
    func addToContainer(_ container: EventHandlersContainer) -> EventHandler
    func dispose()
}

protocol Invocable: AnyObject {
    func invoke(data: Any)
}

public class Event<T> {
    private var eventHandlers = Set<HashableClass>()
    private let lock = Lock()

    public init() {}

    public func raise(_ data: T) {
        for handler in eventHandlers {
            let invocable = handler as! Invocable
            invocable.invoke(data: data)
        }
    }

    @discardableResult
    public func addHandler(_ handler: @escaping (T) -> Void) -> EventHandler {
        let wrapper = EventHandlerWrapper(handler: handler, event: self)
        lock.synchronized {
            eventHandlers.insert(wrapper)
        }
        return wrapper
    }

    func removeHandler(_ handler: EventHandler) {
        if let handler = handler as? HashableClass {
            lock.synchronized {
                eventHandlers.remove(handler)
            }
        }
    }
}



private class EventHandlerWrapper<T>: HashableClass, Invocable, EventHandler {
    typealias Handler = (T) -> Void

    let handler: Handler
    unowned let event: Event<T>
    var disposed = false

    init(handler: @escaping Handler, event: Event<T>) {
        self.handler = handler
        self.event = event
    }

    func addToContainer(_ container: EventHandlersContainer) -> EventHandler {
        container.handlers.append(self)
        return self
    }

    func invoke(data: Any) {
        handler(data as! T)
    }

    func dispose() {
        if disposed == false {
            disposed = true
            event.removeHandler(self)
        }
    }
}


public class EventHandlersContainer {
    fileprivate var handlers = [EventHandler]()

    public init() {}

    deinit {
        disposeAll()
    }

    public func disposeAll() {
        handlers.forEach { handler in
            handler.dispose()
        }
        handlers.removeAll()
    }
}
