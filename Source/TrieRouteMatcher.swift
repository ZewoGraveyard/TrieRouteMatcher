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
            
            for method in route.methods {
                
                // add the method to the path so it is checked
                let path = method.description + route.path
                
                // turn component (string) into an id (integer) for fast comparisons
                let componentIds = path.split("/").map { component -> Int in
                    
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
    }

    func getParameterFromId(id: Int) -> String? {
        guard let parameterChars = self.componentsTrie.findByPayload(id) else { return nil }
        let parameter = parameterChars.dropFirst().reduce("") { $0.0 + String($0.1)} // drop colon (":"), then combine characters into string
        return parameter
    }
    func searchForRoute(head head: Trie<Int, Route>, components: [String], componentIndex startingIndex: Int, inout parameters: [String:String]) -> Route? {

        // topmost route node. children are searched for route matches,
        // if they match, that matching node gets set to head
        var head = head

        // if at any point the trie comes up with multiple options for descent, it is to
        // store the alternatives and the index of the component at which it found the alternative
        // node so that it can backtrack and search through that alternative node if the original
        // node ends up 404'ing
        var alternatives: [(Int, Trie<Int, Route>)] = []

        // go through the components starting at the start index. the start index can change
        // to be more than 0 if the trie ran into a dead-end and goes backwards (recursively) through its alternatives
        componentLoop: for (componentIndex, component) in components[startingIndex..<components.count].enumerate() {

            // search for component in the components dictionary
            let id = componentsTrie.findPayload(component.characters)

            // not found in the dictionary - either parameter or 404
            if id == nil {

                for child in head.children {

                    // if the id of the route component is negative,
                    // it is a parameter route
                    if child.prefix < 0 {
                        head = child
                        parameters[getParameterFromId(child.prefix!)!] = component
                        continue componentLoop
                    }
                }

                // no routes matches
                return nil
            }

            // need to sort these in descending order, otherwise
            // children with negative prefixes (parameters) can take
            // priority over static paths (which they shouldnt)
            head.children.sortInPlace { n1, n2 in
                n1.prefix > n2.prefix
            }

            // gets set to the first node to match. however, since we want to fill up alternatives,
            // we wait until we loop through all the children before descending further down the
            // trie through the preferredHead node
            var preferredHead: Trie<Int, Route>? = nil

            // component exists in the routes
            for child in head.children {

                // normal, static route
                if child.prefix == id {
                    if preferredHead == nil { preferredHead = child }
                    else { alternatives.append((componentIndex + 1, child)) }
                    continue
                }

                // still could be a parameter
                // ex: route.get("/api/:version")
                // request: /api/api
                if child.prefix < 0 {
                    if preferredHead == nil {
                        preferredHead = child
                        parameters[getParameterFromId(child.prefix!)!] = component
                    } else {
                        alternatives.append((componentIndex + 1, child))
                    }
                }
            }

            // route was matched
            if let preferredHead = preferredHead {
                head = preferredHead
                continue
            }

            // the path we just took led to a 404. go through all alternative
            // paths (could be an empty array) and try those as well
            for alternative in alternatives {

                let matched = searchForRoute(head: alternative.1, components: components, componentIndex: alternative.0, parameters: &parameters)

                if matched != nil { return matched }
            }

            // 404 even after going through alternatives. no routes matched
            return nil
        }

        // success! found a route.
        return head.payload
    }

    public func match(request: Request) -> Route? {
        guard let path = request.path else {
            return nil
        }

        let components = [request.method.description] + path.split("/")

        var parameters = [String:String]()

        // start searching for the route from the head of the routesTrie
        let matched = searchForRoute(head: routesTrie, components: components, componentIndex: 0, parameters: &parameters)

        // ensure the route was found
        guard let route = matched else { return nil }

        // no parameters? no problem
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
        return componentsTrie.description + "\n" + routesTrie.description
    }
}
