//
//  main.swift
//  Example
//
//  Created by Yuri Drozdovsky on 7/25/19.
//  Copyright © 2019 drozdovsky. All rights reserved.
//

import Foundation
import DRYSwiftHelpers

func getCurrentTime() -> AsyncTask<String> {
    return AsyncTask<String> { asyncContext in
        let urlRequest = URLRequest(url: URL(string: "http://worldclockapi.com/api/json/utc/now")!, timeoutInterval: 5.0)
        let data = try urlRequest.getData().await(asyncContext)
        return data
    }
}

async { asyncContext -> String? in
    print("Hello from background thread")

    let dataTask1 = async { innerAsyncContext -> Data in
        let urlRequest = URLRequest(url: URL(string: "http://worldclockapi.com/api/json/utc/now")!, timeoutInterval: 5.0)
        let data = try wrapError(urlRequest.getData(asyncContext: innerAsyncContext))
        return data
    }
    let dataTask2 = async { innerAsyncContext -> Data in
        let urlRequest = URLRequest(url: URL(string: "http://worldclockapi.com/api/json/utc/now")!, timeoutInterval: 5.0)
        let data = try wrapError(urlRequest.getData(asyncContext: innerAsyncContext))
        return data
    }
    let dataTask3 = async { innerAsyncContext -> Data in
        let urlRequest = URLRequest(url: URL(string: "http://worldclockapi2.com/api/json/utc/now")!, timeoutInterval: 5.0)
        let data = try wrapError(urlRequest.getData(asyncContext: innerAsyncContext))
        return data
    }

    try wrapError(asyncContext.await(tasks: [dataTask1, dataTask2, dataTask3], timeout: .now() + 1.0, throwFirstError: false))
    let data = dataTask1.resultValue!

    return String(data: data, encoding: .utf8)
}.onSuccess { string in
    print("response: \(string ?? "nil")")
}.catch { error in
    print("Caught error:\n\(error)")
}.finally {
    print("Finally back to main thread")
    CFRunLoopStop(CFRunLoopGetCurrent())
}

CFRunLoopRun()
