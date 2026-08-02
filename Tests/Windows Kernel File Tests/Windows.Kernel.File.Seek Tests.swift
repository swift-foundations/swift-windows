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
    import Testing
    import Windows_32_Kernel_File
    import Windows_Kernel_File

    @Suite struct `Windows Kernel File Tests` {
        @Test func `Seek has its L2 owner type`() {
            func assertOwner<T>(_ facade: T.Type, _ owner: T.Type) {}

            assertOwner(
                Windows.Kernel.File.Seek.self,
                Windows.`32`.Kernel.File.Seek.self
            )
        }
    }
#endif
