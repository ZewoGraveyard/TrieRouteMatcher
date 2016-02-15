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
    private var componentsTrie = Trie<Character, Int>()
    private var routesTrie = Trie<Int, Route>()
    public let routes: [Route]

    public init(routes: [Route]) {
        self.routes = routes

        var nextComponentId = 1

        for route in routes {

            // turn component (string) into an id (integer) for fast comparisons
            let componentIds = route.path.split("/").map { component -> Int in

                // if it already has a component with the same name, use that id
                if let id = componentsTrie.findPayload(component.characters) {
                    return id
                }

                let id: Int

                if component.characters.first == ":" {
                    // if component is a parameter, give it a negative id
                    id = -nextComponentId
                } else {
                    // normal component, give it a positive id
                    id = nextComponentId
                }

                // increment id for next component
                nextComponentId += 1

                // insert the component into the trie with the next id
                componentsTrie.insert(component.characters, payload: id)

                return id
            }

            // insert the components with the end node containing the route
            routesTrie.insert(componentIds, payload: route)
        }
    }

    func getParameterFromId(id: Int) -> String? {
        guard let parameterChars = self.componentsTrie.findByPayload(id) else { return nil }
        let parameter = parameterChars.dropFirst().reduce("") { $0.0 + String($0.1)} // drop colon (":"), then combine characters into string
        return parameter
    }

    public func match(request: Request) -> Route? {
        guard let path = request.path else {
            return nil
        }

        let components = path.split("/")

        // topmost route node. children are searched for route matches,
        // if they match, that matching node gets set to head
        var head = routesTrie

        // pseudo-lazy initiation
        var parameters: [String:String]? = nil

        componentLoop: for component in components {

            // search for component in the components dictionary
            let id = componentsTrie.findPayload(component.characters)


            // either parameter or 404
            if id == nil {

                for child in head.children {

                    // if the id of the route component is negative,
                    // its a parameter
                    if child.prefix < 0 {
                        head = child
                        if parameters == nil { parameters = [String:String]() }
                        parameters![getParameterFromId(child.prefix!)!] = component
                        continue componentLoop
                    }
                }

                // no routes matched
                return nil
            }


            // component exists in the routes
            for child in head.children {

                // still could be a parameter
                // ex: route.get("/api/:version")
                // request: /api/api
                if child.prefix < 0 {
                    head = child
                    if parameters == nil { parameters = [String:String]() }
                    parameters![getParameterFromId(child.prefix!)!] = component
                    continue componentLoop
                }

                // normal, static route
                if child.prefix == id {
                    head = child
                    continue componentLoop
                }
            }

            // no routes matched
            return nil
        }

        // get the actual route
        guard let route = head.payload else { return nil }

        // no parameters? no problem
        guard let pathParameters = parameters else { return route }

        let wrappedRoute = Route(
            methods: route.methods,
            path: route.path,
            middleware: route.middleware,
            responder: Responder { req in
                var req = req
                for (key, parameter) in pathParameters {
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
        return componentsTrie.description + "\n" + routesTrie.description
    }
}
