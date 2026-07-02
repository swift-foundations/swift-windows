# Windows

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Type-safe, policy-free wrappers around Windows kernel syscalls for Swift. Provides I/O Completion Port (IOCP) primitives with typed throws and full Sendable compliance.

---

## Key Features

- **Typed throws end-to-end** – Every error type is statically known; no `any Error` escapes the API surface
- **Swift 6 strict concurrency** – Full `Sendable` compliance with documented thread-safety guarantees
- **I/O Completion Ports** – High-performance async I/O via `CreateIoCompletionPort` and `GetQueuedCompletionStatus`
- **Policy-free design** – Raw syscall wrappers without opinions on scheduling, buffering, or lifecycle
- **Batch dequeuing** – Efficient multi-completion retrieval via `GetQueuedCompletionStatusEx`
- **Cancellation support** – Fire-and-forget and status-returning cancel operations via `CancelIoEx`

---

## Installation

### Package.swift dependency

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-windows.git", from: "0.1.0")
]
```

### Target dependency

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Windows Kernel", package: "swift-windows")
    ]
)
```

### Requirements

- Swift 6.2+
- Windows

---

## Quick Start

```swift
import Windows_Kernel

// Create an I/O completion port
let port = try Kernel.IO.Completion.Port.create(threads: 0)
defer { Kernel.IO.Completion.Port.close(port) }

// Associate a file handle (opened with FILE_FLAG_OVERLAPPED)
try Kernel.IO.Completion.Port.associate(port, handle: fileHandle, key: 1)

// Set up overlapped structure for async operation
var overlapped = Kernel.IO.Completion.Port.Overlapped()

// Initiate async read
let result = try Kernel.IO.Completion.Port.read(fileHandle, into: buffer, overlapped: &overlapped.raw)

// Wait for completion
let item = try Kernel.IO.Completion.Port.Dequeue.single(port, timeout: Kernel.IO.Completion.Port.Error.Code.Wait.infinite)
print("Read \(item.bytes) bytes with key \(item.key)")
```

---

## Architecture

| Type | Description |
|------|-------------|
| `Windows` | Namespace enum for Windows-specific APIs |
| `Kernel.IO.Completion.Port` | I/O Completion Port syscall wrappers |
| `Kernel.IO.Completion.Port.Key` | Completion routing key (integer or pointer) |
| `Kernel.IO.Completion.Port.Overlapped` | Async operation state (`OVERLAPPED` wrapper) |
| `Kernel.IO.Completion.Port.Dequeue` | Single and batch completion retrieval |
| `Kernel.IO.Completion.Port.Cancel` | Cancellation operations (all or specific) |
| `Kernel.IO.Completion.Port.Error` | Typed error cases with Win32 error codes |

---

## Platform Support

| Platform         | CI  | Status        |
|------------------|-----|---------------|
| Windows          | ✅  | Full support  |
| macOS/Linux/iOS  | —   | Not supported |

This package provides Windows-specific IOCP APIs. For cross-platform kernel primitives, see [swift-kernel-primitives](https://github.com/coenttb/swift-kernel-primitives).

---

## Related Packages

### Dependencies

- [swift-kernel-primitives](https://github.com/coenttb/swift-kernel-primitives): Cross-platform kernel types (`Kernel.Descriptor`, `Kernel.Error`)

### Used By

- [swift-io](https://github.com/swift-foundations/swift-io): Async I/O executor built on kernel primitives

---

## License

This project is licensed under the Apache License v2.0. See [LICENSE.md](LICENSE.md) for details.
