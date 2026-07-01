// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-windows",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Windows Kernel",
            targets: ["Windows Kernel"]
        ),
        .library(
            name: "Windows Kernel Descriptor",
            targets: ["Windows Kernel Descriptor"]
        ),
        .library(
            name: "Windows Kernel Socket",
            targets: ["Windows Kernel Socket"]
        ),
        .library(
            name: "Windows Kernel Clock",
            targets: ["Windows Kernel Clock"]
        ),
        .library(
            name: "Windows Kernel File",
            targets: ["Windows Kernel File"]
        ),
        .library(
            name: "Windows Kernel Thread",
            targets: ["Windows Kernel Thread"]
        ),
        .library(
            name: "Windows Kernel Process",
            targets: ["Windows Kernel Process"]
        ),
        .library(
            name: "Windows Test Support",
            targets: ["Windows Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-microsoft/swift-windows-standard.git", branch: "main"),
        // Item 3.5 (closed 2026-05-02): Glob vocabulary relocated from
        // swift-iso-9945 L2 to swift-glob-primitives L1, eliminating the
        // cross-platform asymmetry where swift-windows depended on a
        // POSIX-named package for platform-agnostic vocabulary.
        .package(url: "https://github.com/swift-primitives/swift-glob-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-system-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-random-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-equation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-error-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-path-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-clock-primitives.git", branch: "main"),
    ],
    targets: [
        // MARK: - Descriptor (L3-policy per [PLAT-ARCH-005])
        //
        // Hosts Windows.Kernel.Descriptor — the per-platform descriptor type
        // that the swift-kernel typealias resolves to on Windows. Authorized
        // by L1-types-only-no-exceptions Research doc (RECOMMENDATION,
        // commit 0666a59 in swift-kernel-primitives) and platform-skill cycle
        // 6cc4fde in swift-institute/Skills (revised PLAT-ARCH-005 / 008c / 015).
        .target(
            name: "Windows Kernel Descriptor",
            dependencies: [
                .product(name: "Windows 32 Kernel", package: "swift-windows-standard"),
                .product(name: "Error Primitives", package: "swift-error-primitives"),
                .product(name: "Equation Primitives", package: "swift-equation-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
            ]
        ),
        .target(
            name: "Windows Kernel",
            dependencies: [
                "Windows Kernel Descriptor",
                .product(name: "Windows 32 Kernel", package: "swift-windows-standard"),
                .product(name: "Windows 32 Kernel File", package: "swift-windows-standard"),
                .product(name: "Glob Primitives", package: "swift-glob-primitives"),
                .product(name: "Clock Primitives", package: "swift-clock-primitives"),
                .product(name: "Error Primitives", package: "swift-error-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Random Primitives", package: "swift-random-primitives"),
                .product(name: "System Primitives", package: "swift-system-primitives"),
                .product(name: "Path Primitives", package: "swift-path-primitives"),
            ]
        ),
        // MARK: - Socket (L3-policy per [PLAT-ARCH-005] / [PLAT-ARCH-008e])
        //
        // L3-policy re-export shim. Provides Windows.Kernel.Socket namespace and
        // Windows.Kernel.Socket.Descriptor typealias for the three-tier chain
        // L3-unifier (swift-kernel) → L3-policy (swift-windows) → L2 (swift-windows-32).
        .target(
            name: "Windows Kernel Socket",
            dependencies: [
                "Windows Kernel Descriptor",
                .product(name: "Windows 32 Kernel Socket", package: "swift-windows-standard"),
            ]
        ),
        // MARK: - Clock (L3-policy re-export per [PLAT-ARCH-008e])
        //
        // L3-policy re-export shim. Windows clock surface (Clock.Continuous.now,
        // Clock.Suspending.now extending Clock_Primitives types) is exposed for
        // swift-kernel's Kernel Clock target via the L3-policy product, not direct
        // L2 reach.
        .target(
            name: "Windows Kernel Clock",
            dependencies: [
                .product(name: "Windows 32 Kernel Clock", package: "swift-windows-standard"),
            ]
        ),
        // MARK: - File (L3-policy per [PLAT-ARCH-005] / [PLAT-ARCH-008e])
        //
        // Tier 5-Windows-FOS+Affinity-Combined Phase 4 target (2026-05-02). Hosts
        // the L3-policy `Windows.Kernel.File` typealias to L2-canonical
        // `Windows.\`32\`.Kernel.File`, which transitively exposes the FOS triple
        // (`Offset`/`Size`/`Delta`) recreated at L2 in Phase 2 (commit `cc5ff79`
        // at swift-windows-32). Per principal Q2 disposition, declared as a
        // per-domain target (NOT flat-umbrella merged into Windows Kernel) to
        // keep the three-tier chain navigable per-domain.
        .target(
            name: "Windows Kernel File",
            dependencies: [
                .product(name: "Windows 32 Kernel File", package: "swift-windows-standard"),
            ]
        ),
        // MARK: - Thread (L3-policy per [PLAT-ARCH-005] / [PLAT-ARCH-008e])
        //
        // Tier 5-Windows-FOS+Affinity-Combined Phase 3 target (2026-05-02). Hosts
        // the L3-policy `Windows.Kernel.Thread` typealias to L2-canonical
        // `Windows.\`32\`.Kernel.Thread`, plus the `Affinity.apply(_:)` dispatch
        // method recreated from the Wave 1.9 deletion (commit `afd758d`). Per
        // principal Q2 disposition, declared as a per-domain target (NOT
        // flat-umbrella merged into Windows Kernel) to keep the three-tier chain
        // L3-unifier (swift-kernel) → L3-policy (swift-windows) → L2 (swift-windows-32)
        // navigable per-domain.
        .target(
            name: "Windows Kernel Thread",
            dependencies: [
                .product(name: "Windows 32 Kernel Thread", package: "swift-windows-standard"),
                .product(name: "Windows 32 Kernel System", package: "swift-windows-standard"),
                .product(name: "System Primitives", package: "swift-system-primitives"),
                .product(name: "Error Primitives", package: "swift-error-primitives"),
            ]
        ),
        // MARK: - Process (L3-policy per [PLAT-ARCH-005] / [PLAT-ARCH-008e])
        //
        // swift-process v2 Windows arc Phase C target. Hosts the L3-policy
        // `Windows.Kernel.Process` typealias to L2-canonical
        // `Windows.\`32\`.Kernel.Process` (containing Spawn / Actions / Result /
        // Error / Exit). The three-tier chain on Windows:
        //
        //   Kernel.Process (L3-unifier swift-kernel)
        //     → Windows.Kernel.Process (L3-policy here)
        //       → Windows.\`32\`.Kernel.Process (L2 canonical swift-windows-32)
        //
        // Matches the existing L3 sibling pattern (e.g., Windows Kernel File):
        // the typealias is gated behind #if os(Windows) and assumes the
        // consumer reaches L3 `Windows.Kernel` via the Windows Kernel umbrella
        // target's re-export when building on Windows. POSIX builds skip the
        // typealias entirely.
        .target(
            name: "Windows Kernel Process",
            dependencies: [
                .product(name: "Windows 32 Kernel Process", package: "swift-windows-standard"),
            ]
        ),
        .target(
            name: "Windows Test Support",
            dependencies: [
                "Windows Kernel",
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Windows Kernel Tests",
            dependencies: [
                "Windows Kernel",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
