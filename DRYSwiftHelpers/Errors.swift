//
// Created by Yuri Drozdovsky on 2019-07-25.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

import Foundation

public enum DRYSwiftHelpersError: Error {
    case semaphoreTimedOut
    case httpInvalidResponse
    case httpBadStatusCode(statusCode: Int, data: Data?)
    case asyncTaskTimedOut
    case asyncTaskCancelled
}
