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

    import WinSDK
    import Testing

    // [MOD-038] `Glob` is declared in L1 Glob_Primitives. The implementation file
    // reaches it via `public import`, which permits the type in that module's public
    // API signatures but does NOT re-export it — clients must import it themselves.
    import Glob_Primitives

    // [MOD-038] Same SE-0409 shape: Glob.match takes `borrowing Path.Borrowed`
    // (L1 Path_Primitives), which Windows_Kernel public-imports without re-export.
    import Path_Primitives

    @testable import Windows_Kernel

    extension Glob {
        enum Test {
            @Suite struct Unit {}
            @Suite struct EdgeCase {}
            @Suite struct Integration {}
            @Suite(.serialized) struct Performance {}
        }
    }

    // MARK: - Test Fixture

    /// Converts String to null-terminated UTF-16 for Win32 APIs.
    private func withWideString<R>(
        _ string: String,
        _ body: (UnsafePointer<WCHAR>) -> R
    ) -> R {
        var utf16 = Array(string.utf16)
        utf16.append(0)
        return utf16.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: WCHAR.self, capacity: buffer.count) { wcharPtr in
                body(wcharPtr)
            }
        }
    }

    /// Extracts String from null-terminated WCHAR buffer.
    private func stringFromWideChars(_ buffer: UnsafePointer<WCHAR>, maxLength: Int) -> String {
        var length = 0
        while length < maxLength && buffer[length] != 0 {
            length += 1
        }
        let wcharBuffer = UnsafeBufferPointer(start: buffer, count: length)
        return String(decoding: wcharBuffer, as: UTF16.self)
    }

    /// Recursively removes a directory and its contents.
    private func removeDirectoryRecursively(_ path: String) {
        let winPath = path.replacing("/", with: "\\")
        let searchPath = winPath + "\\*"
        var findData = WIN32_FIND_DATAW()

        let handle = withWideString(searchPath) { wpath in
            FindFirstFileW(wpath, &findData)
        }

        guard handle != INVALID_HANDLE_VALUE else { return }
        defer { FindClose(handle) }

        repeat {
            let name = withUnsafePointer(to: &findData.cFileName) { ptr in
                ptr.withMemoryRebound(to: WCHAR.self, capacity: 260) { wcharPtr in
                    stringFromWideChars(wcharPtr, maxLength: 260)
                }
            }

            if name == "." || name == ".." { continue }

            let fullPath = winPath + "\\" + name
            let isDirectory = (findData.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0

            if isDirectory {
                removeDirectoryRecursively(fullPath)
            } else {
                withWideString(fullPath) { wpath in
                    _ = DeleteFileW(wpath)
                }
            }
        } while FindNextFileW(handle, &findData)

        withWideString(winPath) { wpath in
            _ = RemoveDirectoryW(wpath)
        }
    }

    /// Gets the parent directory path.
    private func parentDirectory(of path: String) -> String {
        var components = path.split(separator: "/", omittingEmptySubsequences: false)
        if components.count > 1 {
            components.removeLast()
        }
        return components.joined(separator: "/")
    }

    /// Creates a temporary directory for testing.
    private func withTestDirectory(
        _ body: (String) throws -> Void
    ) throws {
        // Get temp path
        var tempPathBuffer = [WCHAR](repeating: 0, count: Int(MAX_PATH) + 1)
        let tempPathLen = GetTempPathW(DWORD(tempPathBuffer.count), &tempPathBuffer)
        guard tempPathLen > 0 else {
            throw Glob.Error.io(path: "temp", category: .other)
        }
        let tempPath = stringFromWideChars(tempPathBuffer, maxLength: Int(tempPathLen))

        // Create unique directory name using process ID and monotonic time
        let pid = GetCurrentProcessId()
        let ticks = GetTickCount64()
        let testDir = tempPath + "glob-test-\(pid)-\(ticks)"
        let winTestDir = testDir.replacing("/", with: "\\")

        // Create directory
        let created = withWideString(winTestDir) { wpath in
            CreateDirectoryW(wpath, nil)
        }
        guard created else {
            throw Glob.Error.io(path: testDir, category: .other)
        }

        defer {
            removeDirectoryRecursively(testDir)
        }

        // Use forward slashes for cross-platform API
        let posixPath = testDir.replacing("\\", with: "/")
        try body(posixPath)
    }

    /// Creates files and directories in the test directory.
    private func createTestFiles(in directory: String) throws {
        let files = [
            "file1.txt",
            "file2.txt",
            "file3.md",
            ".hidden.txt",
            "src/main.swift",
            "src/test.swift",
            "src/util.swift",
            "docs/readme.md",
            "docs/guide.md",
            ".config/settings.json",
        ]

        for file in files {
            let fullPath = directory + "/" + file
            let winPath = fullPath.replacing("/", with: "\\")
            let dirPath = parentDirectory(of: fullPath).replacing("/", with: "\\")

            // Create parent directory if needed
            withWideString(dirPath) { wpath in
                _ = CreateDirectoryW(wpath, nil)
            }

            // Create file
            let handle = withWideString(winPath) { wpath in
                CreateFileW(
                    wpath,
                    DWORD(GENERIC_WRITE),
                    0,
                    nil,
                    DWORD(CREATE_NEW),
                    DWORD(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            }
            if handle != INVALID_HANDLE_VALUE {
                CloseHandle(handle)
            }
        }
    }

    // MARK: - String→Path.Borrowed bridging

    // Glob.match takes `borrowing Path.Borrowed`; the tests hold Swift.String paths.
    // These wrappers do the scoped conversion once and unwrap the scope's error
    // wrapper so call sites — including `#expect(throws: Glob.Error.self)` — still
    // observe Glob.Error.
    private func glob(
        _ pattern: Glob.Pattern,
        in directory: Swift.String,
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [Swift.String] {
        do throws(Path.String.Error<Glob.Error>) {
            return try Path.String.Scope()(directory) { (view: borrowing Path.Borrowed) throws(Glob.Error) -> [Swift.String] in
                try Glob.match(pattern: pattern, in: view, options: options)
            }
        } catch {
            switch error {
            case .body(let error): throw error
            case .conversion: throw .io(path: directory, category: .other)
            }
        }
    }

    private func glob(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        in directory: Swift.String,
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [Swift.String] {
        do throws(Path.String.Error<Glob.Error>) {
            return try Path.String.Scope()(directory) { (view: borrowing Path.Borrowed) throws(Glob.Error) -> [Swift.String] in
                try Glob.match(include: include, excluding: excluding, in: view, options: options)
            }
        } catch {
            switch error {
            case .body(let error): throw error
            case .conversion: throw .io(path: directory, category: .other)
            }
        }
    }

    // MARK: - Basic Match Tests

    extension Glob.Test.Unit {
        @Test
        func `Match simple wildcard pattern`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("*.txt")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 2)
                #expect(results.contains(dir + "/file1.txt"))
                #expect(results.contains(dir + "/file2.txt"))
            }
        }

        @Test
        func `Match question mark wildcard`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("file?.txt")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 2)
                #expect(results.contains(dir + "/file1.txt"))
                #expect(results.contains(dir + "/file2.txt"))
            }
        }

        @Test
        func `Match literal pattern`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("file1.txt")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 1)
                #expect(results.contains(dir + "/file1.txt"))
            }
        }

        @Test
        func `Match with path segments`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("src/*.swift")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dir + "/src/main.swift"))
                #expect(results.contains(dir + "/src/test.swift"))
                #expect(results.contains(dir + "/src/util.swift"))
            }
        }

        @Test
        func `Match returns empty for no matches`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("*.xyz")
                let results = try glob(pattern, in: dir)

                #expect(results.isEmpty)
            }
        }
    }

    // MARK: - Double Star Tests

    extension Glob.Test.Unit {
        @Test
        func `Match double star recursive`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("**/*.swift")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dir + "/src/main.swift"))
                #expect(results.contains(dir + "/src/test.swift"))
                #expect(results.contains(dir + "/src/util.swift"))
            }
        }

        @Test
        func `Match double star finds all md files`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("**/*.md")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dir + "/file3.md"))
                #expect(results.contains(dir + "/docs/readme.md"))
                #expect(results.contains(dir + "/docs/guide.md"))
            }
        }
    }

    // MARK: - Character Class Tests

    extension Glob.Test.Unit {
        @Test
        func `Match character class`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("file[12].txt")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 2)
                #expect(results.contains(dir + "/file1.txt"))
                #expect(results.contains(dir + "/file2.txt"))
            }
        }
    }

    // MARK: - Options Tests

    extension Glob.Test.Unit {
        @Test
        func `Dotfiles explicit policy excludes hidden files`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("*.txt")
                let options = Glob.Options(dotfiles: .explicit)
                let results = try glob(pattern, in: dir, options: options)

                #expect(results.count == 2)
                #expect(!results.contains(dir + "/.hidden.txt"))
            }
        }

        @Test
        func `Dotfiles always policy includes hidden files`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("*.txt")
                let options = Glob.Options(dotfiles: .always)
                let results = try glob(pattern, in: dir, options: options)

                #expect(results.count == 3)
                #expect(results.contains(dir + "/.hidden.txt"))
            }
        }

        @Test
        func `Dotfiles never policy excludes hidden files`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern(".*")
                let options = Glob.Options(dotfiles: .never)
                let results = try glob(pattern, in: dir, options: options)

                #expect(results.isEmpty)
            }
        }

        @Test
        func `Explicit dotfile pattern matches hidden files`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern(".*.txt")
                let options = Glob.Options(dotfiles: .explicit)
                let results = try glob(pattern, in: dir, options: options)

                #expect(results.count == 1)
                #expect(results.contains(dir + "/.hidden.txt"))
            }
        }

        @Test
        func `Deterministic ordering sorts results`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("*.txt")
                let options = Glob.Options(ordering: .deterministic)
                let results = try glob(pattern, in: dir, options: options)

                #expect(results == results.sorted())
            }
        }

        @Test
        func `Case insensitive matching`() throws {
            try withTestDirectory { dir in
                // Create a file with uppercase
                let upperPath = dir + "/FILE.TXT"
                let winPath = upperPath.replacing("/", with: "\\")
                let handle = withWideString(winPath) { wpath in
                    CreateFileW(
                        wpath,
                        DWORD(GENERIC_WRITE),
                        0,
                        nil,
                        DWORD(CREATE_NEW),
                        DWORD(FILE_ATTRIBUTE_NORMAL),
                        nil
                    )
                }
                if handle != INVALID_HANDLE_VALUE {
                    CloseHandle(handle)
                }

                let pattern = try Glob.Pattern("*.txt")
                let options = Glob.Options(caseInsensitive: true)
                let results = try glob(pattern, in: dir, options: options)

                #expect(results.contains(upperPath))
            }
        }
    }

    // MARK: - Include/Exclude Tests

    extension Glob.Test.Unit {
        @Test
        func `Match with exclusion pattern`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let include = [try Glob.Pattern("*.txt")]
                let exclude = [try Glob.Pattern("file1.txt")]
                let results = try glob(
                    include: include,
                    excluding: exclude,
                    in: dir
                )

                #expect(results.count == 1)
                #expect(results.contains(dir + "/file2.txt"))
                #expect(!results.contains(dir + "/file1.txt"))
            }
        }

        @Test
        func `Match with multiple include patterns`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let include = [
                    try Glob.Pattern("*.txt"),
                    try Glob.Pattern("*.md"),
                ]
                let results = try glob(include: include, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dir + "/file1.txt"))
                #expect(results.contains(dir + "/file2.txt"))
                #expect(results.contains(dir + "/file3.md"))
            }
        }
    }

    // MARK: - Error Tests

    extension Glob.Test.Unit {
        @Test
        func `Match non-existent directory throws notFound`() throws {
            let pattern = try Glob.Pattern("*.txt")

            #expect(throws: Glob.Error.self) {
                _ = try glob(
                    pattern,
                    in: "C:/nonexistent/path/that/does/not/exist"
                )
            }
        }

        @Test
        func `Match with skip error policy continues on error`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("**/*.txt")
                let options = Glob.Options(onError: .skip)

                // Should not throw, gracefully handles any errors
                let results = try glob(pattern, in: dir, options: options)
                #expect(results.count >= 2)
            }
        }
    }

    // MARK: - Edge Cases

    extension Glob.Test.EdgeCase {
        @Test
        func `Match empty pattern`() throws {
            try withTestDirectory { dir in
                let pattern = try Glob.Pattern("")
                let results = try glob(pattern, in: dir)

                #expect(results.count == 1)
            }
        }

        @Test
        func `Match pattern with only star`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("*")
                let results = try glob(pattern, in: dir)

                #expect(results.count >= 4)
            }
        }
    }

    // MARK: - Windows-Specific Tests

    extension Glob.Test.Unit {
        @Test
        func `Path normalization outputs forward slashes`() throws {
            try withTestDirectory { dir in
                try createTestFiles(in: dir)

                let pattern = try Glob.Pattern("*.txt")
                let results = try glob(pattern, in: dir)

                // All paths should use forward slashes
                for path in results {
                    #expect(!path.contains("\\"), "Path should use forward slashes: \(path)")
                }
            }
        }
    }

#endif
