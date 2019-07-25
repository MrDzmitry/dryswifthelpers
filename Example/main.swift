//
//  main.swift
//  Example
//
//  Created by Yuri Drozdovsky on 7/25/19.
//  Copyright © 2019 drozdovsky. All rights reserved.
//

import Foundation
import DRYSwiftHelpers

async { task -> String? in
    print("Hello from background thread")
    let urlRequest = URLRequest(url: URL(string: "http://worldclockapi2.com/api/json/utc/now2")!, timeoutInterval: 5.0)
    let data = try urlRequest.getData(asyncContext: task)
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
