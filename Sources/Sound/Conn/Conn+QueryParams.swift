//
// Created by Griffin Byatt on 2018-12-30.
//

extension Conn {
    func decodeQueryParams<T>(_ query: T?) -> [String:Param] where T: StringProtocol {
        var queryParams = [String:Param]()

        guard query != nil else {
            return queryParams
        }

        guard let query = String(query!).removingPercentEncoding else {
            return queryParams
        }

        query.split(separator: "&").forEach { queryParam in
            var params = queryParam.split(separator: "=", maxSplits: 1).map { q in String(q) }
            let key = params.removeFirst()

            guard let value = params.popLast() else {
                return
            }

            var components = key.split(separator: "[").map { String($0) }
            let first = components.removeFirst()

            guard first != "]", components.allSatisfy({ $0.hasSuffix("]") }) else {
                return
            }

            let decodedValue = Param(_decodeQueryParams(components, value))

            guard let stored = queryParams[first] else {
                queryParams[first] = decodedValue
                return
            }

            queryParams[first] = Param(stored.merging(to: decodedValue.value))
        }

        return queryParams
    }

    private func _decodeQueryParams(_ keyComponents: [String], _ value: String) -> Paramable {
        var keyComponents = keyComponents
        var current: Paramable = value

        while keyComponents.count > 0 {
            let next = String(keyComponents.removeLast().dropLast(1))
            let prev = Param(current)

            if next.isEmpty {
                current = [prev]
            } else {
                current = [next: prev]
            }
        }

        return current
    }
}