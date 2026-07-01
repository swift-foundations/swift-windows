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

@_exported public import Windows_32_Kernel
@_exported public import Random_Primitives

/// Re-export Kernel namespace from primitives for use within Windows module.
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
