import ProjectDescription

let project = Project(
    name: "DesignSystem",
    settings: .settings(
        base: [
            "DEAD_CODE_STRIPPING": "YES",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release", settings: [
                "SWIFT_OPTIMIZATION_LEVEL": "-Owholemodule",
                "SWIFT_COMPILATION_MODE": "wholemodule",
                "GCC_OPTIMIZATION_LEVEL": "s",
            ]),
        ]
    ),
    targets: [
        .target(
            name: "DesignSystem",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.junha.doffice.designsystem",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/**"],
            dependencies: []
        ),
        .target(
            name: "DesignSystemCatalog",
            destinations: .macOS,
            product: .app,
            bundleId: "com.junha.doffice.designsystem.catalog",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleName": "DS Catalog",
                "CFBundleDisplayName": "도피스 디자인 시스템",
                "NSPrincipalClass": "NSApplication",
            ]),
            sources: ["CatalogSources/**"],
            dependencies: [
                .target(name: "DesignSystem"),
            ]
        ),
        .target(
            name: "DesignSystemTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.junha.doffice.designsystem.tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "DesignSystem"),
            ]
        ),
    ]
)
