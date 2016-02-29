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
    private var routesTrie = Trie<String, Route>()
    public let routes: [Route]

    public init(routes: [Route]) {
        self.routes = routes

        for route in routes {

            for method in route.methods {

                // add the method to the path so it is checked
                let path = method.description + route.path

                // break into components
                let components = path.split("/")

                // insert components into trie with route being the ending payload
                routesTrie.insert(components, payload: route)
            }
        }

        // ensure parameter paths are processed later than static paths
        routesTrie.sort { t1, t2 in
            if t1.prefix?.characters.first == ":" {
                return false
            }
            return true
        }
    }

    func searchForRoute(head head: Trie<String, Route>, components: [String], componentIndex startingIndex: Int, inout parameters: [String:String]) -> Route? {

        // topmost route node. children are searched for route matches,
        // if they match, that matching node gets set to head
        var head = head

        // if at any point the trie comes up with multiple options for descent, it is to
        // store the alternatives and the index of the component at which it found the alternative
        // node so that it can backtrack and search through that alternative node if the original
        // node ends up 404'ing
        var alternatives: [(Int, Trie<String, Route>)] = []

        // go through the components starting at the start index. the start index can change
        // to be more than 0 if the trie ran into a dead-end and goes backwards (recursively) through its alternatives
        componentLoop: for (componentIndex, component) in components[startingIndex..<components.count].enumerate() {

            // the first child to match will be the "preferred" child. other
            // children will go into the alternatives array
            var preferred: Trie<String, Route>?

            for child in head.children {

                // route matches
                if child.prefix == component {
                    if preferred == nil { preferred = child }
                    else { alternatives.append((componentIndex + 1, child)) }
                    continue
                }

                // path parameter
                if child.prefix?.characters.first == ":" {
                    if preferred == nil { preferred = child }
                    else { alternatives.append((componentIndex + 1, child)) }
                    let param = String(child.prefix!.characters.dropFirst())
                    parameters[param] = component
                    continue
                }
            }

            // if there is a preferred child, use that as the next head
            if let preferred = preferred {
                head = preferred
                continue
            }

            // this path was wrong - try the alternatives instead
            for (index, node) in alternatives {
                let matched = searchForRoute(head: node, components: components, componentIndex: index, parameters: &parameters)
                if let matched = matched { return matched }
            }

            // 404
            return nil
        }

        return head.payload
    }

    public func match(request: Request) -> Route? {
        guard let path = request.path else {
            return nil
        }

        let components = [request.method.description] + path.unicodeScalars.split("/").map(String.init)

        var parameters = [String:String]()

        let matched = searchForRoute(head: routesTrie, components: components, componentIndex: 0, parameters: &parameters)

        guard let route = matched else { return nil }

        if parameters.isEmpty {
            return route
        }

        // wrap the route to inject the pathParameters upon receiving a request
        let wrappedRoute = Route(
            methods: route.methods,
            path: route.path,
            middleware: route.middleware,
            responder: Responder { req in
                var req = req
                for (key, parameter) in parameters {
                    req.pathParameters[key] = parameter
                }
                return try route.respond(req)
            }
        )

        return wrappedRoute
    }
}

extension TrieRouteMatcher: CustomStringConvertible {
    public var description: String {
        return routesTrie.description
    }
}
