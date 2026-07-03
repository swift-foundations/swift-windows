// Windows.Random.swift
// Cryptographically-secure random number generation for Windows.

#if os(Windows)

    // MARK: - Platform Implementation

    extension Random {
        /// Fills the buffer with cryptographically-secure random bytes.
        ///
        /// Delegates to ``Windows/Kernel/Random/bCryptGenRandom(_:)-(UnsafeMutableRawBufferPointer)``
        /// which wraps `BCryptGenRandom` from the Windows CNG (Cryptography
        /// Next Generation) API.
        ///
        /// - Parameter buffer: The buffer to fill with random bytes.
        ///   If the buffer is empty, this method returns immediately.
        /// - Throws: `Error.systemError` with the NTSTATUS code on failure.
        ///
        /// ## Example
        ///
        /// ```swift
        /// var bytes = [UInt8](repeating: 0, count: 32)
        /// try bytes.withUnsafeMutableBytes { buffer in
        ///     try Random.fill(buffer)
        /// }
        /// ```
        public static func fill(
            _ buffer: UnsafeMutableRawBufferPointer
        ) throws(Error) {
            try Windows.`32`.Kernel.Random.bCryptGenRandom(buffer)
        }
    }

#endif
