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

public struct TrieRouteMatcher: RouteMatcherType {
    private var routesTrie = Trie<String, RouteType>()
    public let routes: [RouteType]

    public init(routes: [RouteType]) {
        self.routes = routes

        for route in routes {
            // break into components
            let components = route.path.split("/")

            // insert components into trie with route being the ending payload
            routesTrie.insert(components, payload: route)
        }

        // ensure parameter paths are processed later than static paths
        routesTrie.sort { t1, t2 in
            if t1.prefix?.characters.first == ":" {
                return false
            }
            return true
        }
    }

    func searchForRoute(head head: Trie<String, RouteType>, components: IndexingGenerator<[String]>, inout parameters: [String:String]) -> RouteType? {

        var components = components

        // if no more components, we hit the end of the path and 
        // may have matched something
        guard let component = components.next() else {
            return head.payload
        }

        // store each possible path (ie both a static and a parameter)
        // and then go through them all
        var paths = [Trie<String, RouteType>]()

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
        }

        // go through all the paths and recursively try to match them. if
        // any of them match, the route has been matched
        for path in paths {
            let matched = searchForRoute(head: path, components: components, parameters: &parameters)
            if let matched = matched { return matched }
        }

        // we went through all the possible paths and still found nothing. 404
        return nil
    }

    public func match(request: Request) -> RouteType? {
        guard let path = request.path else {
            return nil
        }

        let components = path.unicodeScalars.split("/").map(String.init)
        var parameters: [String: String] = [:]

        let matched = searchForRoute(
            head: routesTrie,
            components: components.generate(),
            parameters: &parameters
        )

        guard let route = matched else {
            return nil
        }

        if parameters.isEmpty {
            return route
        }

        // wrap the route to inject the pathParameters upon receiving a request
        return Route(
            path: route.path,
            actions: route.actions.mapValues { action in
                Action(
                    middleware: action.middleware,
                    responder: Responder { request in
                        var request = request

                        for (key, parameter) in parameters {
                            request.pathParameters[key] = parameter
                        }

                        return try action.responder.respond(request)
                    }
                )
            },
            fallback: route.fallback
        )
    }
}

extension TrieRouteMatcher: CustomStringConvertible {
    public var description: String {
        return routesTrie.description
    }
}

struct Route: RouteType {
    let path: String
    var actions: [Method: Action]
    var fallback: Action

    init(path: String, actions: [Method: Action], fallback: Action) {
        self.path = path
        self.actions = actions
        self.fallback = fallback
    }
}

extension Dictionary {
    func mapValues<T>(transform: Value -> T) -> [Key: T] {
        var dictionary: [Key: T] = [:]

        for (key, value) in self {
            dictionary[key] = transform(value)
        }

        return dictionary
    }
}
