// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-windows open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-windows project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

@_exported public import Random_Primitives
@_exported public import Windows_32_Kernel
@_exported public import Windows_Kernel_Descriptor

/// Cross-module `Kernel` spelling for this package: aliases the L3-policy
/// `Windows.Kernel` enum (declared in the Descriptor target's
/// Windows.Kernel.Namespace.swift), NOT a primitives namespace —
/// swift-kernel-primitives no longer exists.
///
/// LOAD-BEARING: swift-kernel's `Kernel Core` and its dependent sub-targets
/// (Thread / File / Completion) resolve bare `Kernel` on the Windows leg
/// only through this alias, reached via their `@_exported public import
/// Windows_Kernel`. Removing it breaks swift-kernel's Windows compile — do
/// not delete without first relocating the alias into swift-kernel. This is
/// the L3-policy → L3-unifier alias pattern (see [PLAT-ARCH-008k]).
public typealias Kernel = Windows.Kernel

/// Re-export Windows namespace (flows through Windows_32_Kernel via @_exported Core).
public typealias Windows = Windows_32_Kernel.Windows

/// Re-export Random namespace from Random_Primitives.
public typealias Random = Random_Primitives.Random

/// Allow `Windows.Random.fill()` namespace-explicit syntax while sharing the
/// same underlying type across all platforms.
extension Windows {
    public typealias Random = Random_Primitives.Random
}
