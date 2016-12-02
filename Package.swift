import PackageDescription

let package = Package(
    name: "SwiftGD",
    dependencies: [
        .Package(url: "https://github.com/twostraws/Cgd.git", majorVersion: 0, minor: 1)
    ]
)
