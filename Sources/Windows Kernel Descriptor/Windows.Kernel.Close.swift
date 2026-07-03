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

public import Windows_32_Kernel

#if os(Windows)

    extension Windows.Kernel {
        /// Policy-aware Windows handle close.
        ///
        /// L3-policy throwing wrapper composing the L2 typed close syscall
        /// (`Windows.\`32\`.Kernel.Close.close(_:consuming Descriptor)`). After
        /// Wave 4c-Socket Prerequisite (2026-05-01) collapsed
        /// `Windows.Kernel.Descriptor` to a typealias of `Windows.\`32\`.Kernel.Descriptor`,
        /// the round-trip pattern (extract UInt → reconstruct L2 Descriptor) is
        /// eliminated; this wrapper passes the typed Descriptor directly to the
        /// L2 typed close.
        ///
        /// ## Ownership
        ///
        /// ``close(_:)`` consumes the descriptor. After the call, the descriptor
        /// is gone. If `close(_:)` is not called explicitly, the descriptor's
        /// `deinit` closes the handle automatically (best-effort, errors swallowed).
        public enum Close: Sendable {}
    }

    // MARK: - Close

    extension Windows.Kernel.Close {
        /// Close a Windows handle, reporting errors.
        ///
        /// Consumes the descriptor and delegates to the L2 typed close form,
        /// remapping `Windows.\`32\`.Kernel.Close.Error` to `Windows.Kernel.Close.Error`
        /// case-by-case. The L2 form handles disarming + WinSDK call +
        /// GetLastError mapping internally; this L3 wrapper preserves the
        /// L3-policy error type for source compatibility.
        ///
        /// - Parameter descriptor: The handle to close (consumed).
        /// - Throws: ``Error`` on failure.
        public static func close(_ descriptor: consuming Windows.Kernel.Descriptor) throws(Error) {
            do throws(Windows.`32`.Kernel.Close.Error) {
                try Windows.`32`.Kernel.Close.close(descriptor)
            } catch {
                switch error {
                case .handle(let e):
                    throw .handle(e)

                case .platform(let e):
                    throw .platform(e)
                }
            }
        }
    }

#endif
