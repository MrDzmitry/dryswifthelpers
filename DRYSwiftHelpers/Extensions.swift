//
// Created by Yuri Drozdovsky on 2019-07-25.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation


extension URLRequest {
    public func createAsyncTask(checkStatusCode: Bool = true, urlSession: URLSession = URLSession.shared) -> AsyncTask<(data: Data, httpResponse: HTTPURLResponse)> {
        return AsyncTask<(data: Data, httpResponse: HTTPURLResponse)> {
            var result: (Data, HTTPURLResponse)?
            var resultError: Error?
            let semaphore = Semaphore()
            urlSession.dataTask(with: self) { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                defer {
                    semaphore.signal()
                }
                if error != nil {
                    resultError = error
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    resultError = DRYSwiftHelpersError.httpInvalidResponse
                    return
                }
                if checkStatusCode == true && response.statusCode != 200 {
                    resultError = DRYSwiftHelpersError.httpBadStatusCode(statusCode: response.statusCode, data: data)
                    return
                }
                guard let data = data else {
                    resultError = DRYSwiftHelpersError.httpInvalidResponse
                    return
                }
                result = (data, response)
            }.resume()
            semaphore.wait()
            if let error = resultError {
                throw error
            } else {
                return result!
            }
        }
    }
}


