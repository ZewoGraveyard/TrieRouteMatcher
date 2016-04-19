import PackageDescription

let package = Package(
    name: "TrieRouteMatcher",
    dependencies: [
        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/Zewo/PathParameterMiddleware.git", majorVersion: 0, minor: 5),
    ]
)
