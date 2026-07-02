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

// Tier 5-Windows-FOS+Affinity-Combined Phase 3 (2026-05-02): reintroduces
// the L3-policy `Windows.Kernel.Thread.Affinity.apply(_:)` method that was
// deleted in Wave 1.9 option-c REMOVE (commit `afd758d`). Wave 1.9 removed
// this file entirely because the swift-windows-32 L2 spec types it
// dispatched into (`Windows.`32`.Kernel.Thread.Affinity`) had been moved to
// `ISO_9945.Kernel.Thread.Affinity` by Path X G6.D and never relocated to
// the Windows L2 layer (per [PLAT-ARCH-007] swift-windows-32 cannot import
// swift-iso-9945). Phase 1 of this Tier 5 cycle recreated the L2 type at
// `Windows.`32`.Kernel.Thread.Affinity`; this file restores the L3-policy
// dispatch surface that delegates to it.
//
// Differs from the deleted afd758d shape in two ways:
//
// 1. Extends `Windows.Kernel.Thread.Affinity` (post-Path-X-G6.D L3-policy
//    namespace, typealiased to the L2-canonical form) instead of the prior
//    `Windows.Thread.Affinity` site.
// 2. Lives in a per-domain `Windows Kernel Thread` SwiftPM target per
//    principal Q2 disposition (per-domain targets, NOT flat-umbrella).

#if os(Windows)
public import Windows_Kernel
public import Windows_32_Kernel
public import System_Primitives
public import Error_Primitives

extension Windows.Kernel.Thread.Affinity {
    /// Applies affinity to the current thread via `SetThreadAffinityMask`.
    ///
    /// ## Implementation
    /// - `.any`: No-op, returns immediately
    /// - `.cores(set)`: Delegates to L2 `Windows.\`32\`.Kernel.Thread.Affinity.setMask(cores:)`
    /// - `.numaNode(id)`: Resolves node to CPUs via
    ///   `System.Topology.NUMA.discover()` (provided by the
    ///   `Windows 32 Kernel System` target's
    ///   `System.Topology.NUMA.Discover.swift`), then delegates to L2.
    ///
    /// ## Processor Groups
    /// Windows supports >64 CPUs via processor groups. The L2 wrapper currently
    /// supports single-group systems (CPUs 0-63). For multi-group support,
    /// `SetThreadGroupAffinity` would be needed.
    ///
    /// ## Errors
    /// - `.platform(code)`: SetThreadAffinityMask failed
    /// - `.invalidNode(id)`: NUMA node not found in topology
    /// - `.tooManyCPUs`: CPU set exceeds single group capacity (>64)
    ///
    /// - Parameter affinity: The affinity specification.
    /// - Throws: `Windows.Kernel.Thread.Affinity.Error` on failure.
    public static func apply(
        _ affinity: Windows.Kernel.Thread.Affinity
    ) throws(Windows.Kernel.Thread.Affinity.Error) {
        switch affinity.kind {
        case .any:
            return

        case .cores(let cores):
            try Windows.`32`.Kernel.Thread.Affinity.setMask(cores: cores)

        case .numaNode(let nodeID):
            let numa = System.Topology.NUMA.discover()
            guard case .nonUniform(let nodes) = numa,
                  let node = nodes.first(where: { $0.id == nodeID }) else {
                throw .invalidNode(nodeID)
            }
            try Windows.`32`.Kernel.Thread.Affinity.setMask(cores: node.cpus)
        }
    }
}

#endif
