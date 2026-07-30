# ``Windows_Kernel``

@Metadata {
    @DisplayName("Windows Kernel")
    @TitleHeading("Swift Foundations")
}

The L3-policy layer for Windows: `Windows.Kernel` types (directory, device,
environment, glob match, group, IO, inode, link, lock, permission, storage,
time, user) and cryptographically secure random fill, each a typealias or
thin wrapper resolving to the L2-canonical `Windows.32.Kernel` implementation
in `swift-windows-32`.

## When to use this

Reach for this package (or its per-domain sibling products — Descriptor,
Socket, Clock, File, Thread, Process) when code needs a Windows kernel
operation to actually run — it is the middle tier of the three-tier chain
`Kernel` (L3-unifier, `swift-kernel`) → `Windows.Kernel` (L3-policy, here) →
`Windows.32.Kernel` (L2, `swift-windows-32`), kept per-domain rather than
flat-merged so each tier stays navigable. Code that only needs the
cross-platform `Kernel` names should depend on `swift-kernel` instead; code
that needs the L2 Windows API surface directly should depend on
`swift-windows-32`.

## Topics

### Related packages

- [swift-windows-32](https://github.com/swift-microsoft/swift-windows-32) —
  the L2-canonical Windows implementation this package resolves to.
