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

// Tier 5-Windows-FOS+Affinity-Combined Phase 3 (2026-05-02): L3-policy
// `Windows.Kernel.Thread` namespace anchor — collapses to a typealias of the
// L2-canonical `Windows.`32`.Kernel.Thread` per [PLAT-ARCH-005] revised
// (L2-canonical-where-spec-layer-exists). Mirrors the
// `Windows.Kernel.Descriptor → Windows.`32`.Kernel.Descriptor` collapse from
// Wave 4c-Socket Prerequisite (commit 4562214).
//
// ## Layering after Phase 3
//
// | Layer | Site | Behavior |
// |---|---|---|
// | L2 swift-windows-32 | `Windows.\`32\`.Kernel.Thread` (canonical) | Native syscall surface (CreateThread, GetCurrentThread, SwitchToThread) + nested types (Index, ID, Affinity, Affinity.{Kind,Error,Failure,Support}) |
// | L3-policy swift-windows | `Windows.Kernel.Thread` (typealias to L2) | Source-compat name; the `apply(_:)` policy method extends the L2 type via this import path |
// | L3-unifier swift-kernel | `Kernel.Thread = Windows.Kernel.Thread` (on Windows) | Cross-platform name resolves via L3-policy |
//
// Per [PLAT-ARCH-007] swift-windows-32 cannot import swift-iso-9945; the L3
// `apply(_:)` policy method is therefore declared at this L3-policy layer
// (where both L2 swift-windows-32 and System_Primitives are accessible),
// not at L2.

#if os(Windows)
public import Windows_32_Kernel

extension Windows.Kernel {
    /// Windows thread namespace — typealias to the L2-canonical
    /// `Windows.\`32\`.Kernel.Thread` per [PLAT-ARCH-005] revised.
    ///
    /// Nested types (`Affinity`, `Affinity.Kind`, `Affinity.Error`,
    /// `Affinity.Failure`, `Affinity.Support`, `Index`, `ID`) resolve through
    /// the typealias to their L2 canonical declarations.
    public typealias Thread = Windows.`32`.Kernel.Thread
}

#endif
