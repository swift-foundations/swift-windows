// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-windows open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-windows project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// [PLAT-ARCH-008k] Spec/Policy Namespace Split, D1 unification (2026-07-31):
// `Windows.Kernel.File` becomes a distinct empty policy enum instead of a
// whole-namespace typealias to `Windows.`32`.Kernel.File`. The whole-namespace
// collapse let swift-kernel's hoisted vocabulary (`Clone`, `Direct`, `Copy`,
// `Event`, `Affinity`) attach to `Windows.`32`.Kernel.File`/`.Thread` through
// this L3-policy site, producing ambiguity with the parallel hoisted
// declarations at the L3-unifier (swift-foundations/swift-windows#2). Mirrors
// the POSIX-side collapse (swift-foundations/swift-posix#1, a2c061a).
//
// ## Layering after D1
//
// | Layer | Site | Behavior |
// |---|---|---|
// | L2 swift-windows-32 | `Windows.\`32\`.Kernel.File` (canonical) | Win32 file syscall surface + FOS triple (Offset/Size/Delta typealiases to L1 Coordinate/Magnitude/Displacement) |
// | L3-policy swift-windows | `Windows.Kernel.File` (distinct empty enum) | Per-member typealiases below resolve non-hoisted members to their L2 canonical declarations |
// | L3-unifier swift-kernel | `Kernel.File = Windows.Kernel.File` (on Windows) | Cross-platform name resolves via L3-policy; hoisted members (`Clone`, `Direct`, `Copy`) are declared directly on `Kernel.File` and are NOT aliased here |

#if os(Windows)
    public import Windows_Kernel
    @_exported public import Windows_32_Kernel_File

    extension Windows.Kernel {
        /// Windows file namespace (L3-policy).
        ///
        /// A distinct empty enum — not a typealias to the L2-canonical
        /// `Windows.\`32\`.Kernel.File` — so that hoisted L3-unifier
        /// vocabulary (`Clone`, `Direct`, `Copy`) can attach here without
        /// colliding with the parallel L2 declarations.
        public enum File: Sendable {}
    }

    // MARK: - Per-member typealiases to L2 canonical

    extension Windows.Kernel.File {
        /// File attributes — typealias to canonical L2 home.
        public typealias Attributes = Windows.`32`.Kernel.File.Attributes

        /// File ownership — typealias to canonical L2 home.
        public typealias Chown = Windows.`32`.Kernel.File.Chown

        /// File deletion — typealias to canonical L2 home.
        public typealias Delete = Windows.`32`.Kernel.File.Delete

        /// File flush/sync — typealias to canonical L2 home.
        public typealias Flush = Windows.`32`.Kernel.File.Flush

        /// File handle — typealias to canonical L2 home.
        public typealias Handle = Windows.`32`.Kernel.File.Handle

        /// File move — typealias to canonical L2 home.
        public typealias Move = Windows.`32`.Kernel.File.Move

        /// File offset — typealias to canonical L2 home.
        public typealias Offset = Windows.`32`.Kernel.File.Offset

        /// File open — typealias to canonical L2 home.
        public typealias Open = Windows.`32`.Kernel.File.Open

        /// File permissions — typealias to canonical L2 home.
        public typealias Permissions = Windows.`32`.Kernel.File.Permissions

        /// File position seeking — typealias to canonical L2 home.
        public typealias Seek = Windows.`32`.Kernel.File.Seek

        /// File size — typealias to canonical L2 home.
        public typealias Size = Windows.`32`.Kernel.File.Size

        /// File stats — typealias to canonical L2 home.
        public typealias Stats = Windows.`32`.Kernel.File.Stats

        /// File times — typealias to canonical L2 home.
        public typealias Times = Windows.`32`.Kernel.File.Times
    }

#endif
