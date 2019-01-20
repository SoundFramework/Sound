//
// Created by Griffin Byatt on 2019-01-16.
//
public protocol Paramable {
    func isEquivalent(to: Any) -> Bool
    func merging(to param: Paramable) -> Paramable
}

extension String: Paramable {
    public func isEquivalent(to param: Any) -> Bool {
        return self == param as? String
    }

    public func merging(to param: Paramable) -> Paramable {
        return param
    }
}

extension Array: Paramable where Element: Equatable {
    public func isEquivalent(to param: Any) -> Bool {
        guard let param = param as? Array else {
            return false
        }

        return self == param
    }

    public func merging(to param: Paramable) -> Paramable {
        guard let merging = param as? Array else {
            return param
        }

        return self + merging
    }
}

extension Dictionary: Paramable where Value: Equatable {
    public func isEquivalent(to param: Any) -> Bool {
        guard let param = param as? Dictionary else {
            return false
        }

        return self == param
    }

    public func merging(to param: Paramable) -> Paramable {
        guard let merging = param as? Dictionary else {
            return param
        }

        return self.merging(merging) { (_, new) in new }
    }
}

public class Param: Equatable, CustomStringConvertible {
    let value: Paramable

    public var description: String {
        return "\(self.value)"
    }

    public func merging(to param: Paramable) -> Paramable {
        return self.value.merging(to: param)
    }

    public static func == (lhs: Param, rhs: Param) -> Bool {
        return lhs.value.isEquivalent(to: rhs.value)
    }

    public static func == (lhs: Param, rhs: Paramable) -> Bool {
        return lhs.value.isEquivalent(to: rhs)
    }

    public static func == (lhs: Paramable, rhs: Param) -> Bool {
        return rhs.value.isEquivalent(to: lhs)
    }

    init(_ value: Paramable) {
        self.value = value
    }
}