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

// [PLAT-ARCH-008k] Spec/Policy Namespace Split: `Windows.Kernel.Lock` is a
// distinct empty policy enum, not a whole-namespace typealias to the
// L2-canonical `Windows.\`32\`.Kernel.Lock`, so that L3-unifier vocabulary can
// attach here without colliding with the parallel L2 declarations. Mirrors
// `Windows.Kernel.File` in this package and `POSIX.Kernel.Lock` in swift-posix.
//
// ## Layering
//
// | Layer | Site | Behavior |
// |---|---|---|
// | L2 swift-windows-32 | `Windows.\`32\`.Kernel.Lock` (canonical) | `LockFileEx`/`UnlockFileEx` syscall surface, error/range/kind vocabulary, RAII token |
// | L3-policy swift-windows | `Windows.Kernel.Lock` (distinct empty enum) | Per-member typealiases plus throwing wrappers; policy refinements land here |
// | L3-unifier swift-kernel | `Kernel.Lock = Windows.Kernel.Lock` (on Windows) | The one converged byte-range locking name portable code consumes |
//
// `Token` (the `~Copyable` RAII handle) is aliased here alongside every other
// lock member. It is the sole content of the L2 "Windows 32 Kernel Lock"
// target, which now builds on the full matrix: its `Clock.Continuous` access
// sits inside the `os(Windows)` guard on swift-windows-32 `main`.
//
// `Scope` is deliberately absent: it has no Win32 counterpart. A converged
// surface that resolves on one platform and not the other is not converged, so
// `Scope` must not be exposed through the converged `Kernel.Lock` on either
// platform while it remains one-sided.
//
// This target exists because portable code that needs a machine-wide file lock
// previously had no converged owner to consume: swift-posix's "POSIX Kernel
// Lock" was the only realised L3 lock policy, so every consumer reached a POSIX
// substrate unconditionally and broke on Windows. The Win32 half of the surface
// already existed at L2; only this policy tier and the swift-kernel export were
// missing.

#if os(Windows)
    public import Windows_32_Kernel_Lock
    public import Windows_Kernel

    extension Windows.Kernel {
        /// Windows byte-range file-locking namespace (L3-policy).
        public enum Lock: Sendable {}
    }

    // MARK: - Per-member typealiases to L2 canonical

    extension Windows.Kernel.Lock {
        /// Errors thrown by file-locking operations.
        public typealias Error = Windows.`32`.Kernel.Lock.Error

        /// Range descriptor for a lock.
        public typealias Range = Windows.`32`.Kernel.Lock.Range

        /// Lock kind (shared or exclusive).
        public typealias Kind = Windows.`32`.Kernel.Lock.Kind

        /// Lock acquisition mode.
        public typealias Acquire = Windows.`32`.Kernel.Lock.Acquire

        /// RAII handle owning an acquired lock.
        public typealias Token = Windows.`32`.Kernel.Lock.Token

        /// Non-blocking lock operations.
        public enum Immediate: Sendable {}
    }

    // MARK: - Blocking lock / unlock

    extension Windows.Kernel.Lock {
        /// Acquires a lock on a byte range (blocking).
        ///
        /// L3-policy wrapper composing the L2 typed `LockFileEx` form
        /// (`Windows.\`32\`.Kernel.Lock.lock(_:range:kind:)`) with the
        /// `Windows.Kernel.Descriptor` policy typealias.
        ///
        /// - Parameters:
        ///   - descriptor: The file handle.
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        /// - Throws: ``Error`` if the lock cannot be acquired.
        public static func lock(
            _ descriptor: borrowing Windows.Kernel.Descriptor,
            range: Range,
            kind: Kind
        ) throws(Error) {
            try Windows.`32`.Kernel.Lock.lock(descriptor, range: range, kind: kind)
        }

        /// Releases a lock on a byte range.
        ///
        /// L3-policy wrapper composing the L2 typed `UnlockFileEx` form
        /// (`Windows.\`32\`.Kernel.Lock.unlock(_:range:)`).
        ///
        /// - Parameters:
        ///   - descriptor: The file handle.
        ///   - range: The byte range to unlock.
        /// - Throws: ``Error`` if unlocking fails.
        public static func unlock(
            _ descriptor: borrowing Windows.Kernel.Descriptor,
            range: Range
        ) throws(Error) {
            try Windows.`32`.Kernel.Lock.unlock(descriptor, range: range)
        }
    }

    // MARK: - Non-blocking lock (Immediate)

    extension Windows.Kernel.Lock.Immediate {
        /// Attempts to acquire a lock without blocking.
        ///
        /// L3-policy wrapper composing the L2 typed `LockFileEx` +
        /// `LOCKFILE_FAIL_IMMEDIATELY` form
        /// (`Windows.\`32\`.Kernel.Lock.Immediate.lock(_:range:kind:)`).
        ///
        /// - Parameters:
        ///   - descriptor: The file handle.
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        /// - Throws: ``Windows/Kernel/Lock/Error`` if the lock is held by
        ///           another process or the acquisition otherwise fails.
        public static func lock(
            _ descriptor: borrowing Windows.Kernel.Descriptor,
            range: Windows.Kernel.Lock.Range,
            kind: Windows.Kernel.Lock.Kind
        ) throws(Windows.Kernel.Lock.Error) {
            try Windows.`32`.Kernel.Lock.Immediate.lock(descriptor, range: range, kind: kind)
        }
    }

#endif
