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

#if os(Windows)

extension Windows.Kernel.Descriptor {
    /// Readiness categories a caller wants to be notified about for a
    /// handle.
    ///
    /// Cross-paradigm vocabulary — shared by reactor-style readiness
    /// (``Kernel/Event``) and proactor-style completion polling
    /// (``Kernel/Completion``).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Monitor for both read and write readiness.
    /// let interest: Windows.Kernel.Descriptor.Interest = [.read, .write]
    /// ```
    ///
    /// ## Platform Mapping
    ///
    /// | Interest     | Windows WSAPoll |
    /// |--------------|-----------------|
    /// | `.read`      | `POLLRDNORM`    |
    /// | `.write`     | `POLLWRNORM`    |
    /// | `.priority`  | `POLLPRI`       |
    public struct Interest: OptionSet, Sendable, Hashable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Interest in read readiness (data available to read).
        public static let read = Interest(rawValue: 1 << 0)

        /// Interest in write readiness (buffer space available for writing).
        public static let write = Interest(rawValue: 1 << 1)

        /// Interest in priority/out-of-band data.
        public static let priority = Interest(rawValue: 1 << 2)
    }
}

// MARK: - CustomStringConvertible

extension Windows.Kernel.Descriptor.Interest: CustomStringConvertible {
    public var description: Swift.String {
        var parts: [Swift.String] = []
        if contains(.read) { parts.append("read") }
        if contains(.write) { parts.append("write") }
        if contains(.priority) { parts.append("priority") }
        return parts.isEmpty ? "none" : parts.joined(separator: "|")
    }
}

#endif
