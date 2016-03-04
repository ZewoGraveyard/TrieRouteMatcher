// TrieRouteMatcherTests.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
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

@testable import TrieRouteMatcher
import XCTest

class TrieRouteMatcherTests: XCTestCase {
    let ok = Responder { request in
        return Response(status: .OK)
    }

    func testExample() {
        XCTAssert(true)
    }

    func testTrie() {
        var trie = Trie<Character, Int>()

        trie.insert("12345".characters, payload: 10101)
        trie.insert("12456".characters)
        trie.insert("12346".characters)
        trie.insert("12344".characters)
        trie.insert("92344".characters)

        XCTAssert(trie.contains("12345".characters))
        XCTAssert(trie.contains("92344".characters))
        XCTAssert(!trie.contains("12".characters))
        XCTAssert(!trie.contains("12444".characters))
        XCTAssert(trie.findPayload("12345".characters) == 10101)
        XCTAssert(trie.findPayload("12346".characters) == nil)
    }

    func testTrieRouteMatcherMatchesRoutes() {
        testMatcherMatchesRoutes(TrieRouteMatcher.self)
    }

    func testTrieRouteMatcherWithTrailingSlashes() {
        testMatcherWithTrailingSlashes(TrieRouteMatcher.self)
    }

    func testTrieRouteMatcherParsesPathParameters() {
        testMatcherParsesPathParameters(TrieRouteMatcher.self)
    }

    func testPerformanceOfTrieRouteMatcher() {
        measureBlock {
            self.testPerformanceOfMatcher(TrieRouteMatcher.self)
        }
    }

    func testMatcherMatchesRoutes(matcher: RouteMatcherType.Type) {
        let routes: [RouteType] = [
            TestRoute(path: "/hello/world"),
            TestRoute(path: "/hello/dan"),
            TestRoute(path: "/api/:version"),
            TestRoute(path: "/servers/json"),
            TestRoute(path: "/servers/:host/logs")
        ]

        let matcher = matcher.init(routes: routes)

        func route(path: String, shouldMatch: Bool) -> Bool {
            let request = try! Request(method: .GET, uri: path)
            let matched = matcher.match(request)
            return shouldMatch ?  matched != nil : matched == nil
        }

        XCTAssert(route("/hello/world", shouldMatch: true))
        XCTAssert(route("/hello/dan", shouldMatch: true))
        XCTAssert(route("/hello/world/dan", shouldMatch: false))
        XCTAssert(route("/api/v1", shouldMatch: true))
        XCTAssert(route("/api/v2", shouldMatch: true))
        XCTAssert(route("/api/v1/v1", shouldMatch: false))
        XCTAssert(route("/api/api", shouldMatch: true))
        XCTAssert(route("/servers/json", shouldMatch: true))
        XCTAssert(route("/servers/notjson", shouldMatch: false))
        XCTAssert(route("/servers/notjson/logs", shouldMatch: true))
        XCTAssert(route("/servers/json/logs", shouldMatch: true))
    }

    func testMatcherWithTrailingSlashes(matcher: RouteMatcherType.Type) {
        let routes: [RouteType] = [
            TestRoute(path: "/hello/world")
        ]

        let matcher = matcher.init(routes: routes)

        let request1 = try! Request(method: .GET, uri: "/hello/world")
        let request2 = try! Request(method: .GET, uri: "/hello/world/")

        XCTAssert(matcher.match(request1) != nil)
        XCTAssert(matcher.match(request2) != nil)
    }

    func testMatcherParsesPathParameters(matcher: RouteMatcherType.Type) {
        let action = Action(ok)

        let routes: [RouteType] = [
            TestRoute(
                path: "/hello/world",
                actions: [
                    .GET: Action { _ in
                        Response(body: "hello world - not!")
                    }
                ]
            ),
            TestRoute(
                path: "/hello/:location",
                actions: [
                    .GET: Action {
                        Response(body: "hello \($0.pathParameters["location"]!)")
                    }
                ]
            ),
            TestRoute(
                path: "/:greeting/:location",
                actions: [
                    .GET: Action {
                        Response(body: "\($0.pathParameters["greeting"]!) \($0.pathParameters["location"]!)")
                    }
                ]
            )
        ]

        let matcher = matcher.init(routes: routes)

        func body(request: Request) -> String? {
            return try! matcher.match(request)?.respond(request).bodyString
        }

        let helloWorld = try! Request(method: .GET, uri: "/hello/world")
        let helloAmerica = try! Request(method: .GET, uri: "/hello/america")
        let heyAustralia = try! Request(method: .GET, uri: "/hey/australia")

        XCTAssert(body(helloWorld) == "hello world - not!")
        XCTAssert(body(helloAmerica) == "hello america")
        XCTAssert(body(heyAustralia) == "hey australia")
    }

    func testPerformanceOfMatcher(matcher: RouteMatcherType.Type) {
        let action = Action(ok)

        let routePairs: [(HTTP.Method, String)] = [
            // Objects
            (.POST, "/1/classes/:className"),
            (.GET, "/1/classes/:className/:objectId"),
            (.PUT, "/1/classes/:className/:objectId"),
            (.GET, "/1/classes/:className"),
            (.DELETE, "/1/classes/:className/:objectId"),

            // Users
            (.POST, "/1/users"),
            (.GET, "/1/login"),
            (.GET, "/1/users/:objectId"),
            (.PUT, "/1/users/:objectId"),
            (.GET, "/1/users"),
            (.DELETE, "/1/users/:objectId"),
            (.POST, "/1/requestPasswordReset"),

            // Roles
            (.POST, "/1/roles"),
            (.GET, "/1/roles/:objectId"),
            (.PUT, "/1/roles/:objectId"),
            (.GET, "/1/roles"),
            (.DELETE, "/1/roles/:objectId"),

            // Files
            (.POST, "/1/files/:fileName"),

            // Analytics
            (.POST, "/1/events/:eventName"),

            // Push Notifications
            (.POST, "/1/push"),

            // Installations
            (.POST, "/1/installations"),
            (.GET, "/1/installations/:objectId"),
            (.PUT, "/1/installations/:objectId"),
            (.GET, "/1/installations"),
            (.DELETE, "/1/installations/:objectId"),

            // Cloud Functions
            (.POST, "/1/functions"),
        ]

        let requestPairs: [(HTTP.Method, String)] = [
            // Objects
            (.POST, "/1/classes/test"),
            (.GET, "/1/classes/test/test"),
            (.PUT, "/1/classes/test/test"),
            (.GET, "/1/classes/test"),
            (.DELETE, "/1/classes/test/test"),

            // Users
            (.POST, "/1/users"),
            (.GET, "/1/login"),
            (.GET, "/1/users/test"),
            (.PUT, "/1/users/test"),
            (.GET, "/1/users"),
            (.DELETE, "/1/users/test"),
            (.POST, "/1/requestPasswordReset"),

            // Roles
            (.POST, "/1/roles"),
            (.GET, "/1/roles/test"),
            (.PUT, "/1/roles/test"),
            (.GET, "/1/roles"),
            (.DELETE, "/1/roles/test"),

            // Files
            (.POST, "/1/files/test"),

            // Analytics
            (.POST, "/1/events/test"),

            // Push Notifications
            (.POST, "/1/push"),

            // Installations
            (.POST, "/1/installations"),
            (.GET, "/1/installations/test"),
            (.PUT, "/1/installations/test"),
            (.GET, "/1/installations"),
            (.DELETE, "/1/installations/test"),

            // Cloud Functions
            (.POST, "/1/functions"),
        ]

        let routes: [RouteType] = routePairs.map {
            TestRoute(
                path: $0.1,
                actions: [$0.0: action]
            )
        }

        let requests = requestPairs.map {
            Request(method: $0.0, uri: URI(path: $0.1))
        }

        let matcher = matcher.init(routes: routes)

        for _ in 0...50 {
            for request in requests {
                matcher.match(request)
            }
        }
    }
}

struct TestRoute: RouteType {
    let path: String
    let actions: [HTTP.Method: Action]
    
    init(path: String, actions: [HTTP.Method: Action] = [:]) {
        self.path = path
        self.actions = actions
    }
}
