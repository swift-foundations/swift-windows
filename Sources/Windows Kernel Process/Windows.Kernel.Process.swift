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
// the per-platform Process namespace + Spawn API are canonical at L2
// swift-windows-32. This L3-policy file collapses the L3 namespace to a
// typealias of the L2 canonical so cross-platform consumers writing
// `Windows.Kernel.Process` see the same type as
// `Windows.\`32\`.Kernel.Process`.
//
// Mirrors the POSIX-side collapse (POSIX.Kernel.Process namespace at
// swift-posix typealiases to ISO_9945.Kernel.Process).

#if os(Windows)
    public import Windows_Kernel
    @_exported public import Windows_32_Kernel_Process

    extension Windows.Kernel {
        /// Windows process operations namespace — typealias to the
        /// L2-canonical `Windows.\`32\`.Kernel.Process` per [PLAT-ARCH-005]
        /// revised.
        ///
        /// Nested types (``Spawn``, ``Spawn/Actions``, ``Spawn/Result``,
        /// ``Error``, ``Exit``) resolve through the typealias to their L2
        /// canonical declarations.
        public typealias Process = Windows.`32`.Kernel.Process
    }
#endif
