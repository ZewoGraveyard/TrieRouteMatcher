// TrieRouteMatcher.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Dan Appel
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import HTTP
@_exported import PathParameterMiddleware

public struct TrieRouteMatcher: RouteMatcher {
    private var routesTrie = Trie<String, Route>()
    public let routes: [Route]

    public init(routes: [Route]) {
        self.routes = routes

        for route in routes {
            // break into components
            let components = route.path.split(separator: "/")

            // insert components into trie with route being the ending payload
            routesTrie.insert(components, payload: route)
        }

        // ensure parameter paths are processed later than static paths
        routesTrie.sort { t1, t2 in
            func rank(_ t: Trie<String, Route>) -> Int {
                if t.prefix == "*" {
                    return 3
                }
                if t.prefix?.characters.first == ":" {
                    return 2
                }
                return 1
            }

            return rank(t1) < rank(t2)
        }
    }

    func searchForRoute(head: Trie<String, Route>, components: IndexingIterator<[String]>, parameters: inout [String:String]) -> Route? {

        var components = components

        // if no more components, we hit the end of the path and
        // may have matched something
        guard let component = components.next() else {
            return head.payload
        }

        // store each possible path (ie both a static and a parameter)
        // and then go through them all
        var paths = [Trie<String, Route>]()

        for child in head.children {

            // matched static
            if child.prefix == component {
                paths.append(child)
                continue
            }

            // matched parameter
            if child.prefix?.characters.first == ":" {
                paths.append(child)
                let param = String(child.prefix!.characters.dropFirst())
                parameters[param] = component
                continue
            }

            // matched wildstar
            if child.prefix == "*" {
                paths.append(child)
                continue
            }
        }

        // go through all the paths and recursively try to match them. if
        // any of them match, the route has been matched
        for path in paths {

            if let route = path.payload where path.prefix == "*" {
                return route
            }

            let matched = searchForRoute(head: path, components: components, parameters: &parameters)
            if let matched = matched { return matched }
        }

        // we went through all the possible paths and still found nothing. 404
        return nil
    }

    public func match(_ request: Request) -> Route? {
        guard let path = request.path else {
            return nil
        }

        let components = path.unicodeScalars.split(separator: "/").map(String.init)
        var parameters: [String: String] = [:]

        let matched = searchForRoute(
            head: routesTrie,
            components: components.makeIterator(),
            parameters: &parameters
        )

        guard let route = matched else {
            return nil
        }

        if parameters.isEmpty {
            return route
        }

        let parametersMiddleware = PathParameterMiddleware(parameters)

        // wrap the route to inject the pathParameters upon receiving a request
        return BasicRoute(
            path: route.path,
            actions: route.actions.mapValues({parametersMiddleware.chain(to: $0)}),
            fallback: route.fallback
        )
    }
}

extension TrieRouteMatcher: CustomStringConvertible {
    public var description: String {
        return routesTrie.description
    }
}

extension Dictionary {
    func mapValues<T>(_ transform: (Value) -> T) -> [Key: T] {
        var dictionary: [Key: T] = [:]

        for (key, value) in self {
            dictionary[key] = transform(value)
        }

        return dictionary
    }
}
