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

#if os(Windows)
public import Windows_32_Kernel_Socket

extension Windows.Kernel {
    /// Policy-aware Windows socket namespace.
    ///
    /// L3-policy namespace mirroring the L2 spec namespace
    /// `Windows.\`32\`.Kernel.Socket`. Hosts the L3-policy typealias for
    /// `Descriptor` so the three-tier chain
    /// `Kernel.Socket.Descriptor → Windows.Kernel.Socket.Descriptor → Windows.\`32\`.Kernel.Socket.Descriptor`
    /// composes one tier at a time per [PLAT-ARCH-008e].
    public enum Socket: Sendable {}
}

extension Windows.Kernel.Socket {
    /// Cross-platform Windows socket descriptor — L2-canonical at swift-windows-32.
    ///
    /// Per [PLAT-ARCH-005] revised (Wave 4c-Socket Prerequisite II, 2026-05-01):
    /// the per-platform Socket Descriptor is canonical at L2
    /// (`Windows.\`32\`.Kernel.Socket.Descriptor` — UInt64 storage + closesocket-on-deinit);
    /// L3-policy contributes this typealias so the three-tier chain composes
    /// one tier at a time per [PLAT-ARCH-008e].
    public typealias Descriptor = Windows.`32`.Kernel.Socket.Descriptor
}

#endif
