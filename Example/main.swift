//
//  main.swift
//  Example
//
//  Created by Yuri Drozdovsky on 7/25/19.
//  Copyright © 2019 drozdovsky. All rights reserved.
//

import Foundation
import DRYSwiftHelpers

async { () -> String? in
    print("Hello from background thread")

    let urlRequest1 = URLRequest(url: URL(string: "http://worldclockapi.com/api/json/utc/now")!, timeoutInterval: 5.0)
    let dataTask1 = urlRequest1.dataTask()

    let urlRequest2 = URLRequest(url: URL(string: "http://worldclockapi.com/api/json/utc/now")!, timeoutInterval: 5.0)
    let dataTask2 = urlRequest2.dataTask()

    let urlRequest3 = URLRequest(url: URL(string: "http://worldclockapi2.com/api/json/utc/now")!, timeoutInterval: 5.0)
    let dataTask3 = urlRequest3.dataTask()

    try wrapError(await(tasks: [dataTask1, dataTask2, dataTask3], timeout: .now() + 5.0, muteErrors: true))
    let data = dataTask1.resultValue!

    return String(data: data, encoding: .utf8)
}.onSuccess { string in
    print("response: \(string ?? "nil")")
}.onError { error in
    print("Caught error:\n\(error)")
}.finally {
    print("Finally back to main thread")
    CFRunLoopStop(CFRunLoopGetCurrent())
}

CFRunLoopRun()
