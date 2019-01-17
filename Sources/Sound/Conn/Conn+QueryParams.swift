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

            let k = params.removeFirst()
            if let v = params.popLast() {
                queryParams[k] = Param(v)
            }
        }

        return queryParams
    }
}