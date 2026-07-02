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

// Per [PLAT-ARCH-005] revised (L2-canonical-where-spec-layer-exists),
// the per-platform Pipe namespace + Descriptors are canonical at L2
// swift-windows-32. This L3-policy file collapses the L3 namespace to a
// typealias of the L2 canonical so cross-platform consumers writing
// `Windows.Kernel.Pipe` see the same type as `Windows.\`32\`.Kernel.Pipe`.
//
// Mirrors the POSIX-side collapse (POSIX.Kernel.Pipe namespace at
// swift-posix typealiases to ISO_9945.Kernel.Pipe).

#if os(Windows)
public import Windows_Kernel
public import Windows_32_Kernel_File

extension Windows.Kernel {
    /// Windows anonymous-pipe namespace — typealias to the L2-canonical
    /// `Windows.\`32\`.Kernel.Pipe` per [PLAT-ARCH-005] revised.
    ///
    /// Nested types (``Descriptors``, ``Error``, the ``pipe()`` factory)
    /// resolve through the typealias to their L2 canonical declarations.
    public typealias Pipe = Windows.`32`.Kernel.Pipe
}

#endif
