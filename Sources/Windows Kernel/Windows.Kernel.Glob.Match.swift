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

internal import Glob_Primitives
internal import Windows_32_Kernel_File

// MARK: - Windows Glob Implementation (extends Glob)
//
// Wave 4a-Glob (Item 3 of post-Path-X cycles, 2026-05-01):
// - [PLAT-ARCH-008j] violation closed: WinSDK calls relocated to L2
//   `Windows.\`32\`.Kernel.File.Find` typed primitives.
// - Namespace switched from `Windows.Kernel.Glob` (was undeclared at L3)
//   to top-level `Glob` (relocated to L1 swift-glob-primitives per Item 3.5; mirrors POSIX-side L3-policy at swift-posix).
// - Signature aligned with POSIX-side: `match(pattern:in:options:body:)`
//   takes `borrowing Path.Borrowed` + body closure `(Swift.String) -> Void`.
// - Glob vocabulary types (Pattern, Segment, Atom, Options, Error) reached
//   via `internal import Glob_Primitives` — relocated from L2
//   `ISO_9945.Kernel.Glob` to L1 top-level `Glob` per Item 3.5 (closed
//   2026-05-02), eliminating the cross-platform asymmetry where this
//   Windows-side L3 file used to depend on a POSIX-named package.

extension Glob {
    /// Matches files using a glob pattern (Windows implementation),
    /// yielding each match to the body closure.
    ///
    /// Streams results directly — no intermediate collection. Each matched
    /// path is yielded as it is found during directory traversal.
    public static func match(
        pattern: Pattern,
        in directory: borrowing Path.Borrowed,
        options: Options = .init(),
        body: (Swift.String) -> Void
    ) throws(Error) {
        let root = Path(directory.span)
        let directoryString = unsafe Swift.String(
            cString: UnsafeRawPointer(root.view.pointer).assumingMemoryBound(to: CChar.self)
        )

        if options.ordering == .deterministic {
            var results: [Swift.String] = []
            try matchSegments(
                pattern.segments,
                segmentIndex: 0,
                currentPath: directoryString,
                options: options
            ) { results.append($0) }
            results.sort()
            for result in results {
                body(result)
            }
        } else {
            try matchSegments(
                pattern.segments,
                segmentIndex: 0,
                currentPath: directoryString,
                options: options,
                body: body
            )
        }
    }

    /// Matches files using multiple patterns with exclusions, yielding each match.
    public static func match(
        include: [Pattern],
        excluding: [Pattern] = [],
        in directory: borrowing Path.Borrowed,
        options: Options = .init(),
        body: (Swift.String) -> Void
    ) throws(Error) {
        var allMatches: Set<Swift.String> = []

        for pattern in include {
            try match(pattern: pattern, in: directory, options: options) { path in
                allMatches.insert(path)
            }
        }

        for pattern in excluding {
            try match(pattern: pattern, in: directory, options: options) { path in
                allMatches.remove(path)
            }
        }

        if options.ordering == .deterministic {
            for result in allMatches.sorted() {
                body(result)
            }
        } else {
            for result in allMatches {
                body(result)
            }
        }
    }

    /// Convenience: matches files using a glob pattern, returning collected results.
    public static func match(
        pattern: Pattern,
        in directory: borrowing Path.Borrowed,
        options: Options = .init()
    ) throws(Error) -> [Swift.String] {
        var results: [Swift.String] = []
        try match(pattern: pattern, in: directory, options: options) { results.append($0) }
        return results
    }

    /// Convenience: matches files using multiple patterns with exclusions,
    /// returning collected results.
    public static func match(
        include: [Pattern],
        excluding: [Pattern] = [],
        in directory: borrowing Path.Borrowed,
        options: Options = .init()
    ) throws(Error) -> [Swift.String] {
        var results: [Swift.String] = []
        try match(include: include, excluding: excluding, in: directory, options: options) {
            results.append($0)
        }
        return results
    }
}

// MARK: - Private Implementation

extension Glob {
    /// Recursively matches segments against the filesystem, yielding each match.
    private static func matchSegments(
        _ segments: [Segment],
        segmentIndex: Int,
        currentPath: Swift.String,
        options: Options,
        depth: Int = 0,
        body: (Swift.String) -> Void
    ) throws(Error) {
        if let maxDepth = options.maxDepth, depth > maxDepth {
            return
        }
        guard segmentIndex < segments.count else {
            body(posixPath(currentPath))
            return
        }
        let segment = segments[segmentIndex]
        switch segment {
        case .literal(let bytes):
            let name = Swift.String(decoding: bytes, as: UTF8.self)
            let nextPath = appendPath(currentPath, name)
            if pathExists(nextPath) {
                try matchSegments(
                    segments,
                    segmentIndex: segmentIndex + 1,
                    currentPath: nextPath,
                    options: options,
                    depth: depth,
                    body: body
                )
            }

        case .pattern(let atoms):
            let entries = try listDirectoryWithAttributes(currentPath, options: options)
            for entry in entries {
                if matchAtoms(atoms, against: entry.name, options: options) {
                    let nextPath = appendPath(currentPath, entry.name)
                    try matchSegments(
                        segments,
                        segmentIndex: segmentIndex + 1,
                        currentPath: nextPath,
                        options: options,
                        depth: depth,
                        body: body
                    )
                }
            }

        case .doubleStar:
            // ** matches zero or more path segments
            try matchSegments(
                segments,
                segmentIndex: segmentIndex + 1,
                currentPath: currentPath,
                options: options,
                depth: depth,
                body: body
            )

            let entries = try listDirectoryWithAttributes(currentPath, options: options)
            for entry in entries {
                let nextPath = appendPath(currentPath, entry.name)
                if isTraversableDirectory(
                    isDirectory: entry.isDirectory,
                    isReparsePoint: entry.isReparsePoint,
                    followSymlinks: options.followSymlinks
                ) {
                    if shouldSkipDotfile(entry.name, options: options, forDoubleStar: true) {
                        continue
                    }
                    try matchSegments(
                        segments,
                        segmentIndex: segmentIndex,
                        currentPath: nextPath,
                        options: options,
                        depth: depth + 1,
                        body: body
                    )
                }
            }
        }
    }

    /// Matches atoms against a filename.
    private static func matchAtoms(
        _ atoms: [Atom],
        against name: Swift.String,
        options: Options
    ) -> Bool {
        if name.hasPrefix(".") && name != "." && name != ".." {
            switch options.dotfiles {
            case .never:
                return false
            case .always:
                break
            case .explicit:
                if let first = atoms.first {
                    switch first {
                    case .literal(let bytes) where !bytes.isEmpty && bytes[0] == 0x2E /* . */:
                        break
                    default:
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        let scalars = Array(name.unicodeScalars)
        return matchAtomsRecursive(
            atoms,
            atomIndex: 0,
            scalars: scalars,
            scalarIndex: 0,
            options: options
        )
    }

    /// Recursive atom matching with backtracking for *.
    private static func matchAtomsRecursive(
        _ atoms: [Atom],
        atomIndex: Int,
        scalars: [Unicode.Scalar],
        scalarIndex: Int,
        options: Options
    ) -> Bool {
        if atomIndex >= atoms.count {
            return scalarIndex >= scalars.count
        }
        let atom = atoms[atomIndex]
        switch atom {
        case .literal(let bytes):
            let literalString = Swift.String(decoding: bytes, as: UTF8.self)
            let literalScalars = Array(literalString.unicodeScalars)
            for (i, literal) in literalScalars.enumerated() {
                let idx = scalarIndex + i
                guard idx < scalars.count else { return false }
                if options.caseInsensitive {
                    let a = foldCase(scalars[idx])
                    let b = foldCase(literal)
                    if a != b { return false }
                } else {
                    if scalars[idx] != literal { return false }
                }
            }
            return matchAtomsRecursive(
                atoms,
                atomIndex: atomIndex + 1,
                scalars: scalars,
                scalarIndex: scalarIndex + literalScalars.count,
                options: options
            )

        case .question:
            guard scalarIndex < scalars.count else { return false }
            return matchAtomsRecursive(
                atoms,
                atomIndex: atomIndex + 1,
                scalars: scalars,
                scalarIndex: scalarIndex + 1,
                options: options
            )

        case .star:
            for i in scalarIndex...scalars.count {
                if matchAtomsRecursive(
                    atoms,
                    atomIndex: atomIndex + 1,
                    scalars: scalars,
                    scalarIndex: i,
                    options: options
                ) {
                    return true
                }
            }
            return false

        case .scalar(let scalarClass):
            guard scalarIndex < scalars.count else { return false }
            let scalar = scalars[scalarIndex]
            let testScalar = options.caseInsensitive ? foldCase(scalar) : scalar
            if scalarClass.matches(testScalar) {
                return matchAtomsRecursive(
                    atoms,
                    atomIndex: atomIndex + 1,
                    scalars: scalars,
                    scalarIndex: scalarIndex + 1,
                    options: options
                )
            }
            return false
        }
    }

    /// ASCII case folding (A-Z to a-z).
    private static func foldCase(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        let value = scalar.value
        if value >= 0x41 && value <= 0x5A {
            return Unicode.Scalar(value + 0x20)!
        }
        return scalar
    }

    /// Checks if a name should be skipped based on dotfile policy.
    private static func shouldSkipDotfile(
        _ name: Swift.String,
        options: Options,
        forDoubleStar: Bool
    ) -> Bool {
        guard name.hasPrefix(".") && name != "." && name != ".." else {
            return false
        }
        switch options.dotfiles {
        case .always:
            return false
        case .never:
            return true
        case .explicit:
            return forDoubleStar
        }
    }
}

// MARK: - Filesystem Helpers (compose typed L2 Windows.`32`.Kernel.File.Find)

extension Glob {
    /// A typed view of one file-find entry: name plus directory/reparse-point flags.
    private typealias DirectoryEntry = (
        name: Swift.String,
        isDirectory: Bool,
        isReparsePoint: Bool
    )

    /// Lists directory entries with their typed attributes via L2
    /// `Windows.\`32\`.Kernel.File.Find`. The L2 Handle is RAII —
    /// `FindClose` runs automatically on deinit.
    private static func listDirectoryWithAttributes(
        _ path: Swift.String,
        options: Options
    ) throws(Error) -> [DirectoryEntry] {
        let searchPath = windowsPath(path) + "\\*"

        let opened: (Windows.`32`.Kernel.File.Find.Handle, Windows.`32`.Kernel.File.Find.Entry)
        do throws(Windows.`32`.Kernel.File.Find.Error) {
            opened = try Windows.`32`.Kernel.File.Find.first(path: searchPath)
        } catch {
            if options.onError == .skip {
                return []
            }
            throw mapFindError(error, path: path)
        }

        var handle = opened.0
        let firstEntry = opened.1
        var entries: [DirectoryEntry] = []

        if firstEntry.name != "." && firstEntry.name != ".." {
            entries.append((firstEntry.name, firstEntry.isDirectory, firstEntry.isReparsePoint))
        }

        while let entry = handle.next() {
            if entry.name != "." && entry.name != ".." {
                entries.append((entry.name, entry.isDirectory, entry.isReparsePoint))
            }
        }

        return entries
    }

    /// Checks if a path exists via L2 `Windows.\`32\`.Kernel.File.pathExists`.
    private static func pathExists(_ path: Swift.String) -> Bool {
        Windows.`32`.Kernel.File.pathExists(windowsPath(path))
    }

    /// Checks if entry is a traversable directory.
    private static func isTraversableDirectory(
        isDirectory: Bool,
        isReparsePoint: Bool,
        followSymlinks: Bool
    ) -> Bool {
        if !isDirectory { return false }
        if !followSymlinks && isReparsePoint { return false }
        return true
    }

    /// Appends a path component using the canonical glob separator (`/`).
    private static func appendPath(_ base: Swift.String, _ component: Swift.String) -> Swift.String {
        if base.hasSuffix("/") || base.hasSuffix("\\") {
            return base + component
        }
        return base + "/" + component
    }

    /// Converts cross-platform path to Windows path.
    ///
    /// Preserves `\\?\` extended-length prefix and converts UNC patterns
    /// (`//server/share`) to Windows form (`\\server\share`).
    private static func windowsPath(_ path: Swift.String) -> Swift.String {
        if path.hasPrefix("\\\\?\\") {
            return path
        }
        if path.hasPrefix("//") {
            return "\\\\" + path.dropFirst(2).replacing("/", with: "\\")
        }
        return path.replacing("/", with: "\\")
    }

    /// Converts Windows path to cross-platform glob path (`/` separator).
    private static func posixPath(_ path: Swift.String) -> Swift.String {
        if path.hasPrefix("\\\\?\\") {
            return path
        }
        return path.replacing("\\", with: "/")
    }
}

// MARK: - Error Mapping

extension Glob {
    /// Maps L2 `Windows.\`32\`.Kernel.File.Find.Error` to typed L1 Glob.Error
    /// (preserving the iso-9945 stable error categories).
    private static func mapFindError(
        _ error: Windows.`32`.Kernel.File.Find.Error,
        path: Swift.String
    ) -> Error {
        switch error {
        case .accessDenied:
            return .accessDenied(path: path)
        case .notFound:
            return .notFound(path: path)
        case .notDirectory:
            return .notDirectory(path: path)
        case .tooManyOpenFiles:
            return .io(path: path, category: .tooManyOpenFiles)
        case .nameTooLong:
            return .io(path: path, category: .nameTooLong)
        case .io:
            return .io(path: path, category: .read)
        }
    }
}

#endif
