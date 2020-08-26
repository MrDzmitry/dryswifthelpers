//
// Created by Yuri Drozdovsky on 2019-07-25.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation


extension URLRequest {
    public func createAsyncTask(checkStatusCode: Bool = true, urlSession: URLSession = URLSession.shared) -> AsyncTask<(data: Data, httpResponse: HTTPURLResponse)> {
        let task = AsyncTask<(data: Data, httpResponse: HTTPURLResponse)>()

        let dataTask = urlSession.dataTask(with: self) { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error != nil {
                task.setResult(.error(error!))
                return
            }
            guard let response = response as? HTTPURLResponse else {
                task.setResult(.error(DRYSwiftHelpersError.httpInvalidResponse))
                return
            }
            if checkStatusCode == true && response.statusCode != 200 {
                task.setResult(.error(DRYSwiftHelpersError.httpBadStatusCode(statusCode: response.statusCode, data: data)))
                return
            }
            guard let data = data else {
                task.setResult(.error(DRYSwiftHelpersError.httpInvalidResponse))
                return
            }
            task.setResult(.value((data, response)))
        }

        task.cancellationHandler = {
            dataTask.cancel()
        }

        dataTask.resume()
        return task
    }
}


