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
    let ok = BasicResponder { request in
        return Response(status: .ok)
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

    func testTrieRouteMatcherMatchesWildstars() {
        testMatcherMatchesWildstars(TrieRouteMatcher.self)
    }

    func testPerformanceOfTrieRouteMatcher() {
        measurePerformance {
            self.testPerformanceOfMatcher(TrieRouteMatcher.self)
        }
    }

    func testMatcherMatchesRoutes(_ matcher: RouteMatcher.Type) {
        let routes: [Route] = [
            TestRoute(path: "/hello/world"),
            TestRoute(path: "/hello/dan"),
            TestRoute(path: "/api/:version"),
            TestRoute(path: "/servers/json"),
            TestRoute(path: "/servers/:host/logs")
        ]

        let matcher = matcher.init(routes: routes)

        func route(path: String, shouldMatch: Bool) -> Bool {
            let request = try! Request(method: .get, uri: path)
            let matched = matcher.match(request)
            return shouldMatch ?  matched != nil : matched == nil
        }

        XCTAssert(route(path: "/hello/world", shouldMatch: true))
        XCTAssert(route(path: "/hello/dan", shouldMatch: true))
        XCTAssert(route(path: "/hello/world/dan", shouldMatch: false))
        XCTAssert(route(path: "/api/v1", shouldMatch: true))
        XCTAssert(route(path: "/api/v2", shouldMatch: true))
        XCTAssert(route(path: "/api/v1/v1", shouldMatch: false))
        XCTAssert(route(path: "/api/api", shouldMatch: true))
        XCTAssert(route(path: "/servers/json", shouldMatch: true))
        XCTAssert(route(path: "/servers/notjson", shouldMatch: false))
        XCTAssert(route(path: "/servers/notjson/logs", shouldMatch: true))
        XCTAssert(route(path: "/servers/json/logs", shouldMatch: true))
    }

    func testMatcherWithTrailingSlashes(_ matcher: RouteMatcher.Type) {
        let routes: [Route] = [
            TestRoute(path: "/hello/world")
        ]

        let matcher = matcher.init(routes: routes)

        let request1 = try! Request(method: .get, uri: "/hello/world")
        let request2 = try! Request(method: .get, uri: "/hello/world/")

        XCTAssert(matcher.match(request1) != nil)
        XCTAssert(matcher.match(request2) != nil)
    }

    func testMatcherParsesPathParameters(_ matcher: RouteMatcher.Type) {
        let action = ok

        let routes: [Route] = [
            TestRoute(
                path: "/hello/world",
                actions: [
                    .get: BasicResponder { _ in
                        Response(body: "hello world - not!")
                    }
                ]
            ),
            TestRoute(
                path: "/hello/:location",
                actions: [
                    .get: BasicResponder {
                        Response(body: "hello \($0.pathParameters["location"]!)")
                    }
                ]
            ),
            TestRoute(
                path: "/:greeting/:location",
                actions: [
                    .get: BasicResponder {
                        Response(body: "\($0.pathParameters["greeting"]!) \($0.pathParameters["location"]!)")
                    }
                ]
            )
        ]

        let matcher = matcher.init(routes: routes)

        func body(request: Request) -> String? {
            var response = try! matcher.match(request)?.respond(to: request)
            return try! String(data: response!.body.becomeBuffer())
        }

        let helloWorld = try! Request(method: .get, uri: "/hello/world")
        let helloAmerica = try! Request(method: .get, uri: "/hello/america")
        let heyAustralia = try! Request(method: .get, uri: "/hey/australia")

        XCTAssert(body(request: helloWorld) == "hello world - not!")
        XCTAssert(body(request: helloAmerica) == "hello america")
        XCTAssert(body(request: heyAustralia) == "hey australia")
    }

    func testMatcherMatchesWildstars(_ matcher: RouteMatcher.Type) {

        func testRoute(path: String, response: String) -> Route {
            return TestRoute(path: path, actions: [.get: BasicResponder { _ in Response(body: response) }])
        }

        let routes: [Route] = [
            testRoute(path: "/*", response: "wild"),
            testRoute(path: "/hello/*", response: "hello wild"),
            testRoute(path: "/hello/dan", response: "hello dan"),
        ]

        let matcher = matcher.init(routes: routes)

        func route(path: String, expectedResponse: String) -> Bool {
            let request = try! Request(method: .get, uri: path)
            let matched = matcher.match(request)

            var response = try! matched!.respond(to: request)
            return try! String(data: response.body.becomeBuffer()) == expectedResponse
        }

        XCTAssert(route(path: "/a/s/d/f", expectedResponse: "wild"))
        XCTAssert(route(path: "/hello/asdf", expectedResponse: "hello wild"))
        XCTAssert(route(path: "/hello/dan", expectedResponse: "hello dan"))
    }

    func testPerformanceOfMatcher(_ matcher: RouteMatcher.Type) {
        let action = ok

        let routePairs: [(HTTP.Method, String)] = [
            // Objects
            (.post, "/1/classes/:className"),
            (.get, "/1/classes/:className/:objectId"),
            (.put, "/1/classes/:className/:objectId"),
            (.get, "/1/classes/:className"),
            (.delete, "/1/classes/:className/:objectId"),

            // Users
            (.post, "/1/users"),
            (.get, "/1/login"),
            (.get, "/1/users/:objectId"),
            (.put, "/1/users/:objectId"),
            (.get, "/1/users"),
            (.delete, "/1/users/:objectId"),
            (.post, "/1/requestPasswordReset"),

            // Roles
            (.post, "/1/roles"),
            (.get, "/1/roles/:objectId"),
            (.put, "/1/roles/:objectId"),
            (.get, "/1/roles"),
            (.delete, "/1/roles/:objectId"),

            // Files
            (.post, "/1/files/:fileName"),

            // Analytics
            (.post, "/1/events/:eventName"),

            // Push Notifications
            (.post, "/1/push"),

            // Installations
            (.post, "/1/installations"),
            (.get, "/1/installations/:objectId"),
            (.put, "/1/installations/:objectId"),
            (.get, "/1/installations"),
            (.delete, "/1/installations/:objectId"),

            // Cloud Functions
            (.post, "/1/functions"),
        ]

        let requestPairs: [(HTTP.Method, String)] = [
            // Objects
            (.post, "/1/classes/test"),
            (.get, "/1/classes/test/test"),
            (.put, "/1/classes/test/test"),
            (.get, "/1/classes/test"),
            (.delete, "/1/classes/test/test"),

            // Users
            (.post, "/1/users"),
            (.get, "/1/login"),
            (.get, "/1/users/test"),
            (.put, "/1/users/test"),
            (.get, "/1/users"),
            (.delete, "/1/users/test"),
            (.post, "/1/requestPasswordReset"),

            // Roles
            (.post, "/1/roles"),
            (.get, "/1/roles/test"),
            (.put, "/1/roles/test"),
            (.get, "/1/roles"),
            (.delete, "/1/roles/test"),

            // Files
            (.post, "/1/files/test"),

            // Analytics
            (.post, "/1/events/test"),

            // Push Notifications
            (.post, "/1/push"),

            // Installations
            (.post, "/1/installations"),
            (.get, "/1/installations/test"),
            (.put, "/1/installations/test"),
            (.get, "/1/installations"),
            (.delete, "/1/installations/test"),

            // Cloud Functions
            (.post, "/1/functions"),
        ]

        let routes: [Route] = routePairs.map {
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

    func measurePerformance(_ block: () -> Void) {
        #if os(OSX)
            measure(block)
        #endif
    }
}

extension TrieRouteMatcherTests {
    static var allTests: [(String, TrieRouteMatcherTests -> () throws -> Void)] {
        return [
                   ("testTrie", testTrie),
                   ("testTrieRouteMatcherMatchesRoutes", testTrieRouteMatcherMatchesRoutes),
                   ("testTrieRouteMatcherWithTrailingSlashes", testTrieRouteMatcherWithTrailingSlashes),
                   ("testTrieRouteMatcherParsesPathParameters", testTrieRouteMatcherParsesPathParameters),
                   ("testTrieRouteMatcherMatchesWildstars", testTrieRouteMatcherMatchesWildstars),
                   ("testPerformanceOfTrieRouteMatcher", testPerformanceOfTrieRouteMatcher)
        ]
    }
}

struct TestRoute: Route {
    let path: String
    let actions: [HTTP.Method: Responder]
    
    init(path: String, actions: [HTTP.Method: Responder] = [:]) {
        self.path = path
        self.actions = actions
    }
}
