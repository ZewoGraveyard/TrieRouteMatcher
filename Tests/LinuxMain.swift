#if os(Linux)

import XCTest
@testable import TrieRouteMatcherTestSuite

XCTMain([
    testCase(TrieRouteMatcherTests.allTests)
])

#endif
