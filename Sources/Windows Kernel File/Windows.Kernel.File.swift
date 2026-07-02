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

// Tier 5-Windows-FOS+Affinity-Combined Phase 4 (2026-05-02): L3-policy
// `Windows.Kernel.File` namespace anchor — collapses to a typealias of the
// L2-canonical `Windows.`32`.Kernel.File` per [PLAT-ARCH-005] revised
// (L2-canonical-where-spec-layer-exists). Mirrors the
// `Windows.Kernel.Descriptor → Windows.`32`.Kernel.Descriptor` collapse from
// Wave 4c-Socket Prerequisite (commit `4562214`) and the
// `Windows.Kernel.Thread → Windows.`32`.Kernel.Thread` collapse from
// Phase 3 of this cycle.
//
// ## Layering after Phase 4
//
// | Layer | Site | Behavior |
// |---|---|---|
// | L2 swift-windows-32 | `Windows.\`32\`.Kernel.File` (canonical) | Win32 file syscall surface (Open, Seek, Move, Stats, Flush, Find, Copy, Delete, Rename, Attributes, Times) + FOS triple (Offset/Size/Delta typealiases to L1 Coordinate/Magnitude/Displacement) |
// | L3-policy swift-windows | `Windows.Kernel.File` (typealias to L2) | Source-compat name; nested types resolve through the typealias |
// | L3-unifier swift-kernel | `Kernel.File = Windows.Kernel.File` (on Windows) | Cross-platform name resolves via L3-policy |

#if os(Windows)
public import Windows_Kernel
@_exported public import Windows_32_Kernel_File

extension Windows.Kernel {
    /// Windows file namespace — typealias to the L2-canonical
    /// `Windows.\`32\`.Kernel.File` per [PLAT-ARCH-005] revised.
    ///
    /// Nested types (`Offset`, `Size`, `Delta`, `Open`, `Seek`, `Move`,
    /// `Stats`, `Flush`, `Find`, `Copy`, `Delete`, `Rename`, `Attributes`,
    /// `Times`) resolve through the typealias to their L2 canonical
    /// declarations.
    public typealias File = Windows.`32`.Kernel.File
}

#endif
