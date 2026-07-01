// POSIX descriptor exports.swift parallel: re-export the L1 namespace
// shells through the L2-shared `Windows_32_Kernel` umbrella so
// that swift-kernel typealias chain (Phase 3) sees the type via the L3
// re-export layer per [PLAT-ARCH-006].
@_exported public import Windows_32_Kernel
