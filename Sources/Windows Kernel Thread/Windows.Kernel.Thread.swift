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
// `Windows.Kernel.Thread` becomes a distinct empty policy enum instead of a
// whole-namespace typealias to `Windows.`32`.Kernel.Thread`. The whole-namespace
// collapse let swift-kernel's hoisted vocabulary (`Affinity`) attach to
// `Windows.`32`.Kernel.Thread` through this L3-policy site, producing
// ambiguity with the parallel hoisted declaration at the L3-unifier
// (swift-foundations/swift-windows#2). Mirrors the POSIX-side collapse
// (swift-foundations/swift-posix#1, a2c061a).
//
// Per D2 (coordinator, 2026-07-31), the `apply(_:)` dispatch that previously
// extended `Windows.Kernel.Thread.Affinity` at this L3-policy layer is
// superseded: kernel performs the affinity-kind switch and calls
// `Windows.`32`.Kernel.Thread.Affinity.setMask(cores:)` directly. See
// `Windows.Kernel.Thread.Affinity.Apply.swift` deletion in this same change.
//
// ## Layering after D1
//
// | Layer | Site | Behavior |
// |---|---|---|
// | L2 swift-windows-32 | `Windows.\`32\`.Kernel.Thread` (canonical) | Native syscall surface (CreateThread, GetCurrentThread, SwitchToThread) + nested types (Index, ID, Error, Handle, Affinity, Affinity.{Kind,Error,Failure,Support}) |
// | L3-policy swift-windows | `Windows.Kernel.Thread` (distinct empty enum) | Per-member typealiases below resolve non-hoisted members to their L2 canonical declarations |
// | L3-unifier swift-kernel | `Kernel.Thread = Windows.Kernel.Thread` (on Windows) | Cross-platform name resolves via L3-policy; the hoisted `Affinity` member is declared directly on `Kernel.Thread` and is NOT aliased here |

#if os(Windows)
    public import Windows_Kernel
    @_exported public import Windows_32_Kernel

    extension Windows.Kernel {
        /// Windows thread namespace (L3-policy).
        ///
        /// A distinct empty enum — not a typealias to the L2-canonical
        /// `Windows.\`32\`.Kernel.Thread` — so that hoisted L3-unifier
        /// vocabulary (`Affinity`) can attach here without colliding with
        /// the parallel L2 declaration.
        public enum Thread: Sendable {}
    }

    // MARK: - Per-member typealiases to L2 canonical

    extension Windows.Kernel.Thread {
        /// Thread error — typealias to canonical L2 home.
        public typealias Error = Windows.`32`.Kernel.Thread.Error

        /// Thread handle — typealias to canonical L2 home.
        public typealias Handle = Windows.`32`.Kernel.Thread.Handle

        /// Thread identifier — typealias to canonical L2 home.
        public typealias ID = Windows.`32`.Kernel.Thread.ID

        /// Thread mutex — typealias to canonical L2 home.
        public typealias Mutex = Windows.`32`.Kernel.Thread.Mutex

        /// Thread condition variable — typealias to canonical L2 home.
        public typealias Condition = Windows.`32`.Kernel.Thread.Condition
    }

#endif
