//
// Created by Yuri Drozdovsky on 2019-07-25.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation


extension URLRequest {
    public func dataTask(asyncContext: AsyncContext, checkStatusCode: Bool = true) -> AsyncTask<Data> {
        return AsyncTask<Data> { asyncContext in
            var resultData: Data?
            var resultError: Error?
            URLSession.shared.dataTask(with: self) { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                defer {
                    asyncContext.resume()
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
                resultData = data
            }.resume()
            asyncContext.suspend()
            if let error = resultError {
                throw error
            } else {
                return resultData!
            }
        }
    }
}


