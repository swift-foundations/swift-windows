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

// Wave 2 Tier 1a Phase 4 (Windows.Kernel L3-policy namespace anchor):
// Per [PLAT-ARCH-008k] Spec/Policy Namespace Split, swift-windows L3
// owns the L3-policy `Windows.Kernel` namespace, distinct from the L2
// spec form `Windows.`32`.Kernel` in swift-windows-32. Prior to Wave 2,
// swift-windows-32 (then swift-windows-standard) declared
// `extension Windows { public enum Kernel: Sendable {} }` directly; the
// L2-side declaration relocated under `Windows.`32`` per Phase 3, so
// swift-windows L3 must declare its own `Windows.Kernel` here.
//
// The L3-unifier swift-kernel resolves cross-platform `Kernel.X` via
// `public typealias Kernel = Windows.Kernel` to this L3-policy form.

public import Windows_32_Core

extension Windows_32_Core.Windows {
    /// Root namespace for L3-policy Windows kernel APIs.
    public enum Kernel: Sendable {}
}
