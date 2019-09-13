//
// Created by Yuri Drozdovsky on 2019-08-02.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

public class HashableClass: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func ==(lhs: HashableClass, rhs: HashableClass) -> Bool {
        return lhs === rhs
    }
}
