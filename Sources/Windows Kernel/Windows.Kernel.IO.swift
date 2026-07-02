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

// L3-policy alias per [PLAT-ARCH-005] revised / [PLAT-ARCH-008k]: the
// L2-canonical form lives in swift-windows-standard's Kernel Core (carried by
// the Windows 32 Kernel umbrella this target already re-exports); swift-kernel
// resolves cross-platform `Kernel.IO` through this alias (the POSIX legs
// resolve theirs via ISO_9945).

#if os(Windows)

extension Windows.Kernel {
    /// Windows I/O operations namespace — typealias to the L2-canonical
    /// `Windows.\`32\`.Kernel.IO`.
    public typealias IO = Windows.`32`.Kernel.IO
}
#endif
