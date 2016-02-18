//
//  TrieRouteMatcherTests.swift
//  TrieRouteMatcher
//
//  Created by Dan Appel on 2/17/16.
//
//

@testable import TrieRouteMatcher
import XCTest

class TrieRouteMatcherTests: XCTestCase {

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

    func testTrieRouteMatcherWithRouter() {
        testMatcherMatchesRoutes(TrieRouteMatcher.self)
    }

    func testTrieRouteMatcherWithTrailingSlashes() {
        testMatcherWithTrailingSlashes(TrieRouteMatcher.self)
    }

    func testTrieRouteMatcherMatchesMethods() {
        testMatcherMatchesMethods(TrieRouteMatcher.self)
    }

    func testTrieRouteMatcherParsesPathParameters() {
        testMatcherParsesPathParameters(TrieRouteMatcher.self)
    }


    func testMatcherMatchesRoutes(matcher: RouteMatcherType.Type) {

        let responder = Responder { request in
            return Response(status: .OK)
        }

        let routes = [
            Route(methods: [.GET], path: "/hello/world", middleware: [], responder: responder),
            Route(methods: [.GET], path: "/hello/dan", middleware: [], responder: responder),
            Route(methods: [.GET], path: "/api/:version", middleware: [], responder: responder),
            Route(methods: [.GET], path: "/servers/json", middleware: [], responder: responder),
            Route(methods: [.GET], path: "/servers/:host/logs", middleware: [], responder: responder)
        ]

        let matcher = matcher.init(routes: routes)

        func route(path: String, shouldMatch: Bool) -> Bool {
            let request = try! Request(method: .GET, uri: path)
            let matched = matcher.match(request)
            if shouldMatch { return matched != nil } else { return matched == nil }
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
        let responder = Responder { request in
            return Response(status: .OK)
        }

        let routes = [
            Route(methods: [.GET], path: "/hello/world", middleware: [], responder: responder)
        ]

        let matcher = matcher.init(routes: routes)

        let request1 = try! Request(method: .GET, uri: "/hello/world")
        let request2 = try! Request(method: .GET, uri: "/hello/world/")

        XCTAssert(matcher.match(request1) != nil)
        XCTAssert(matcher.match(request2) != nil)
    }

    func testMatcherMatchesMethods(matcher: RouteMatcherType.Type) {

        let routes = [
            Route(methods: [.GET], path: "/hello/world", middleware: [], responder: Responder { _ in return Response(body: "get request") }),
            Route(methods: [.POST], path: "/hello/world", middleware: [], responder: Responder { _ in return Response(body: "post request") }),
            Route(methods: [.POST], path: "/hello/world123", middleware: [], responder: Responder { _ in return Response(body: "post request 2") })
        ]

        let matcher = matcher.init(routes: routes)

        let getRequest1 = try! Request(method: .GET, uri: "/hello/world")
        let postRequest1 = try! Request(method: .POST, uri: "/hello/world")

        let getRequest2 = try! Request(method: .GET, uri: "/hello/world123")
        let postRequest2 = try! Request(method: .POST, uri: "/hello/world123")

        XCTAssert(try matcher.match(getRequest1)!.respond(getRequest1).bodyString == "get request")
        XCTAssert(try matcher.match(postRequest1)!.respond(postRequest1).bodyString == "post request")

        XCTAssert(matcher.match(getRequest2) == nil)
        XCTAssert(matcher.match(postRequest2) != nil)
    }

    func testMatcherParsesPathParameters(matcher: RouteMatcherType.Type) {

        let routes = [
            Route(methods: [.GET], path: "/hello/world", middleware: [], responder:  Responder {_ in return Response(body: "hello world - not!") }),
            Route(methods: [.GET], path: "/hello/:location", middleware: [], responder: Responder { return Response(body: "hello \($0.pathParameters["location"]!)") }),
            Route(methods: [.POST], path: "/hello/:location", middleware: [], responder: Responder { return Response(body: "hello \($0.pathParameters["location"]!)") }),
            Route(methods: [.GET], path: "/:greeting/:location", middleware: [], responder: Responder { return Response(body: "\($0.pathParameters["greeting"]!) \($0.pathParameters["location"]!)") })
        ]

        let matcher = matcher.init(routes: routes)

        func body(request: Request) -> String {
            return try! matcher.match(request)!.respond(request).bodyString!
        }

        let helloWorld = try! Request(method: .GET, uri: "/hello/world")
        let helloAmerica = try! Request(method: .GET, uri: "/hello/america")
        let postHelloWorld = try! Request(method: .POST, uri: "/hello/world")
        let heyAustralia = try! Request(method: .GET, uri: "/hey/australia")

        XCTAssert(body(helloWorld) == "hello world - not!")
        XCTAssert(body(helloAmerica) == "hello america")
        XCTAssert(body(postHelloWorld) == "hello world")
        XCTAssert(body(heyAustralia) == "hey australia")
    }
}
