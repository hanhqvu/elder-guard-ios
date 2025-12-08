import ProjectDescription

let swiftVersion = "5.0"

let debugScheme: Scheme =
	.scheme(
		name: "Debug", shared: true,
		buildAction: .buildAction(targets: ["YouGuard"]),
		testAction: .targets(["YouGuard"]),
		runAction: .runAction(
			executable: "YouGuard"
		)
	)

let settings: Settings = .settings(
	base: [
		"PROJECT_BASE": "PROJECT_BASE",
		"SWIFT_VERSION": "\(swiftVersion)"
	],
	configurations: [
		.debug(name: "Debug", xcconfig: "Configurations/Base.xcconfig"),
		.release(name: "Release", xcconfig: "Configurations/Base.xcconfig")
	]
)

let dependencies: [TargetDependency] = [
	.external(name: "NukeUI"),
	.package(product: "StreamWebRTC", type: .runtime),
	.package(product: "SwiftLintBuildToolPlugin", type: .plugin)
]

let destinations: Set<Destination> = [Destination.iPhone]

let swiftFormatScript = TargetScript.pre(
	script: """
		export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
		if which swiftformat >/dev/null; then
		  swiftformat "$SRCROOT" --swift-version \(swiftVersion)
		else
		  echo "error: SwiftFormat not installed, please install it." && exit 1
		fi
		""",
	name: "Run SwiftFormat",
	inputPaths: ["${SRCROOT}"],
	outputPaths: [],
	basedOnDependencyAnalysis: false
)

let project = Project(
	name: "YouGuard",
	packages: [
		.package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.57.0"),
		.package(url: "https://github.com/GetStream/stream-video-swift-webrtc.git", .branch("main"))
	],
	settings: settings,
	targets: [
		.target(
			name: "YouGuard",
			destinations: destinations,
			product: .app,
			bundleId: "com.3143.YouGuard",
			deploymentTargets: .iOS("18.0"),
			infoPlist: .extendingDefault(
				with: [
					"UILaunchScreen": [
						"UIColorName": "",
						"UIImageName": ""
					],
					"NSAppTransportSecurity": [
						"NSAllowsArbitraryLoads": true,
						"NSAllowsLocalNetworking": true
					]
				]
			),
			resources: .resources(
				["YouGuard/Resources"],
				privacyManifest: .privacyManifest(
					tracking: false,
					trackingDomains: [],
					collectedDataTypes: [
						[
							"NSPrivacyCollectedDataType":
								"NSPrivacyCollectedDataTypePreciseLocation",
							"NSPrivacyCollectedDataTypeTracking": false,
							"NSPrivacyCollectedDataTypePurposes": [
								"NSPrivacyCollectedDataTypePurposeAppFunctionality"
							]
						],
						[
							"NSPrivacyCollectedDataType":
								"NSPrivacyCollectedDataTypeCoarseLocation",
							"NSPrivacyCollectedDataTypeTracking": false,
							"NSPrivacyCollectedDataTypePurposes": [
								"NSPrivacyCollectedDataTypePurposeAppFunctionality"
							]
						]
					],
					accessedApiTypes: [
						[
							"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
							"NSPrivacyAccessedAPITypeReasons": [
								"CA92.1"
							]
						]
					]
				)
			),
			buildableFolders: [
				"YouGuard/Sources",
				"YouGuard/Resources"
			],
			entitlements: .file(path: "YouGuard/YouGuard.entitlements"),
			scripts: [swiftFormatScript],
			dependencies: dependencies
		),
		.target(
			name: "YouGuardTests",
			destinations: .iOS,
			product: .unitTests,
			bundleId: "dev.tuist.YouGuardTests",
			infoPlist: .default,
			buildableFolders: [
				"YouGuard/Tests"
			],
			dependencies: [.target(name: "YouGuard")]
		)
	],
	schemes: [
		debugScheme
	]
)
