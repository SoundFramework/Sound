//
// Created by Griffin Byatt on 2019-01-16.
//
public protocol Paramable {
    func isEquivalent(to: Any) -> Bool
}

extension String: Paramable {
    public func isEquivalent(to param: Any) -> Bool {
        return self == param as? String
    }
}

extension Array: Paramable where Element: Equatable {
    public func isEquivalent(to param: Any) -> Bool {
        guard let param = param as? Array else {
            return false
        }

        return self == param
    }
}

extension Dictionary: Paramable where Value: Equatable {
    public func isEquivalent(to param: Any) -> Bool {
        guard let param = param as? Dictionary else {
            return false
        }

        return self == param
    }
}

public class Param: Equatable, CustomStringConvertible {
    let value: Paramable

    public var description: String {
        return "\(self.value)"
    }

    public static func == (lhs: Param, rhs: Paramable) -> Bool {
        return lhs.value.isEquivalent(to: rhs)
    }

    public static func == (lhs: Paramable, rhs: Param) -> Bool {
        return rhs.value.isEquivalent(to: lhs)
    }

    public static func == (lhs: Param, rhs: Param) -> Bool {
        return lhs.value.isEquivalent(to: rhs.value)
    }

    init(_ value: Paramable) {
        self.value = value
    }
}