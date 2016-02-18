//
//  TrieRouteMatcherTests.swift
//  TrieRouteMatcher
//
//  Created by Dan Appel on 2/17/16.
//
//

import Router
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

        let router = Router(matcher: TrieRouteMatcher.self) { route in
            route.get("/hello/world") {_ in print("1"); return Response(status: .OK)}
            route.get("/hello/dan") {_ in print("2"); return Response(status: .OK)}
            route.get("/api/:version") {_ in print("3"); return Response(status: .OK)}
            route.get("/servers/json") {_ in print("4"); return Response(status: .OK)}
            route.get("/servers/:host/logs") {_ in print("5"); return Response(status: .OK)}
        }

        func route(path: String, shouldMatch: Bool) -> Bool {
            let req = try! Request(method: .GET, uri: path)

            let status = try! router.respond(req).status
            if shouldMatch {
                return status != .NotFound
            } else {
                return status == .NotFound
            }
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

    func testTrieRouteMatcherWithTrailingSlashes() {
        let router = Router(matcher: TrieRouteMatcher.self) { route in
            route.get("/hello/world") {_ in print("hello!"); return Response(status: .OK) }
        }

        let request1 = try! Request(method: .GET, uri: "/hello/world")
        let request2 = try! Request(method: .GET, uri: "/hello/world/")

        XCTAssert(try router.respond(request1).status != .NotFound)
        XCTAssert(try router.respond(request2).status != .NotFound)
    }
    
    func testTrieRouteMatcherMatchesMethodsProperly() {
        let router = Router(matcher: TrieRouteMatcher.self) { route in
            route.get("/hello/world") {_ in return Response(body: "get request") }
            route.post("/hello/world") {_ in return Response(body: "post request") }
            route.post("/hello/world123") {_ in return Response(body: "post request 2") }
        }

        let getRequest1 = try! Request(method: .GET, uri: "/hello/world")
        let postRequest1 = try! Request(method: .POST, uri: "/hello/world")

        let getRequest2 = try! Request(method: .GET, uri: "/hello/world123")
        let postRequest2 = try! Request(method: .POST, uri: "/hello/world123")

        XCTAssert(try router.respond(getRequest1).bodyString == "get request")
        XCTAssert(try router.respond(postRequest1).bodyString == "post request")

        XCTAssert(try router.respond(getRequest2).status == .NotFound)
        XCTAssert(try router.respond(postRequest2).status != .NotFound)
    }
}
