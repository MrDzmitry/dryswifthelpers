//
// Created by Yuri Drozdovsky on 2019-08-02.
// Copyright (c) 2019 drozdovsky. All rights reserved.
//

class HashableClass: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    static func ==(lhs: HashableClass, rhs: HashableClass) -> Bool {
        return lhs === rhs
    }
}
