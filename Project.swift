import ProjectDescription

let swiftVersion = "5.0"

let debugScheme: Scheme =
	.scheme(
		name: "Debug", shared: true,
		buildAction: .buildAction(targets: ["ElderGuard"]),
		testAction: .targets(["ElderGuard"]),
		runAction: .runAction(
			executable: "ElderGuard"
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
	name: "ElderGuard",
	packages: [
		.package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.57.0"),
		.package(url: "https://github.com/GetStream/stream-video-swift-webrtc.git", .branch("main"))
	],
	settings: settings,
	targets: [
		.target(
			name: "ElderGuard",
			destinations: destinations,
			product: .app,
			bundleId: "com.3143.YouGuard",
			deploymentTargets: .iOS("18.0"),
			infoPlist: .extendingDefault(
				with: [
					"UILaunchScreen": [
						"UIColorName": "",
						"UIImageName": ""
					]
				]
			),
			resources: .resources(
				["ElderGuard/Resources"],
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
				"ElderGuard/Sources",
				"ElderGuard/Resources"
			],
			entitlements: .file(path: "ElderGuard/ElderGuard.entitlements"),
			scripts: [swiftFormatScript],
			dependencies: dependencies
		),
		.target(
			name: "ElderGuardTests",
			destinations: .iOS,
			product: .unitTests,
			bundleId: "dev.tuist.ElderGuardTests",
			infoPlist: .default,
			buildableFolders: [
				"ElderGuard/Tests"
			],
			dependencies: [.target(name: "ElderGuard")]
		)
	],
	schemes: [
		debugScheme
	]
)
