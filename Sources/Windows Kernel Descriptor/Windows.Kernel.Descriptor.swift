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

@_spi(Syscall) public import Windows_32_Kernel

#if os(Windows)

    // MARK: - Windows Descriptor — typealias to L2-canonical Windows.`32`.Kernel.Descriptor (Wave 4c-Socket Prerequisite, 2026-05-01)
    //
    // Per [PLAT-ARCH-005] revised: when an L2 spec layer exists for the platform,
    // the per-platform Descriptor is canonical at L2. Win32 has the swift-windows-32
    // spec layer, so `Windows.\`32\`.Kernel.Descriptor` is the canonical type;
    // `Windows.Kernel.Descriptor` collapses to a typealias.
    //
    // ## Layering after Wave 4c-Socket Prerequisite
    //
    // | Layer | Site | Behavior |
    // |---|---|---|
    // | L1 swift-kernel-primitives | (no Descriptor type) | L1-types-only-no-exceptions per [PLAT-ARCH-008c] |
    // | L2 swift-windows-32 | `Windows.\`32\`.Kernel.Descriptor` (canonical) | Native HANDLE-shaped UInt + CloseHandle-on-deinit policy + @_spi(Syscall) `init(_rawValue:)` and `_rawValue` accessor |
    // | L3-policy swift-windows | `Windows.Kernel.Descriptor` (typealias to L2) | Source-compat name |
    // | L3-unifier swift-kernel | `Kernel.Descriptor = Windows.\`32\`.Kernel.Descriptor` (on Windows) | Cross-platform name resolves to L2 canonical |
    //
    // Mirrors the POSIX-side collapse (POSIX.Kernel.Descriptor → typealias of
    // ISO_9945.Kernel.Descriptor). Round-trip elimination mechanism per the
    // POSIX-side close-note applies symmetrically.

    extension Windows.Kernel {
        /// Windows handle — typealias to the L2-canonical
        /// `Windows.\`32\`.Kernel.Descriptor` per [PLAT-ARCH-005] revised.
        ///
        /// The `~Copyable` move-only wrapper lives at L2 swift-windows-32. This
        /// typealias preserves the `Windows.Kernel.Descriptor` source-compat
        /// name; nested types (`Validity`, `Duplicate`, `Interest`) resolve
        /// through the typealias.
        public typealias Descriptor = Windows.`32`.Kernel.Descriptor
    }

#endif
