import ProjectDescription

let infoPlist: [String: Plist.Value] = [
    "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
    "CFBundleExecutable": "$(EXECUTABLE_NAME)",
    "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": "도피스",
    "CFBundleDisplayName": "도피스",
    "CFBundlePackageType": "$(PRODUCT_BUNDLE_TYPE)",
    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
    "LSMinimumSystemVersion": "$(MACOSX_DEPLOYMENT_TARGET)",
    "CFBundleIconFile": "AppIcon",
    "NSPrincipalClass": "NSApplication",
    "NSScreenCaptureUsageDescription": "도피스는 실행 중인 Claude Code 세션을 감지하기 위해 프로세스 정보를 조회합니다. 화면 녹화 기능은 사용하지 않습니다.",
]

let project = Project(
    name: "Doffice",
    settings: .settings(
        base: [
            "MARKETING_VERSION": "0.0.37",
            "CURRENT_PROJECT_VERSION": "1",
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
            name: "Doffice",
            destinations: .macOS,
            product: .app,
            bundleId: "com.junha.doffice",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: infoPlist),
            sources: ["Sources/**"],
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/WorkManApp.entitlements"]),
            ],
            entitlements: "Resources/WorkManApp.entitlements",
            dependencies: [
                .project(target: "DofficeKit", path: .relativeToRoot("Projects/DofficeKit")),
                .project(target: "DesignSystem", path: .relativeToRoot("Projects/DesignSystem")),
            ]
        ),
    ]
)
