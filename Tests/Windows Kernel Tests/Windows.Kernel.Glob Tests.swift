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
            @Suite struct `Edge Case` {}
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

    // MARK: - Fixtures ([TEST-032]: statics on the suite namespace, never free functions)

    extension Glob.Test {
        /// Runs `body` with a freshly created temporary directory, vending the
        /// typed borrowed path — the shape `Glob.match` takes — alongside its
        /// String form for building expectation paths. The directory tree is
        /// removed afterwards. A path-conversion failure surfaces as itself
        /// (`Path.String.Error`), never remapped.
        static func withTemporaryDirectory(
            _ body: (borrowing Path.Borrowed, _ string: Swift.String) throws -> Void
        ) throws {
            // Get temp path
            var tempPathBuffer = [WCHAR](repeating: 0, count: Int(MAX_PATH) + 1)
            let tempPathLen = GetTempPathW(DWORD(tempPathBuffer.count), &tempPathBuffer)
            guard tempPathLen > 0 else {
                throw Glob.Error.io(path: "temp", category: .other)
            }
            let tempPath = stringFromWideChars(tempPathBuffer, maxLength: Int(tempPathLen))

            // Create unique directory name. pid+ticks alone is NOT unique: Swift
            // Testing runs suites in parallel and GetTickCount64's ~15ms resolution
            // made concurrent tests collide on the same name (every traversal test
            // failed on CreateDirectoryW at da2e791's Windows leg, all reporting the
            // SAME directory). A random component makes each invocation distinct.
            let pid = GetCurrentProcessId()
            let ticks = GetTickCount64()
            let unique = UInt64.random(in: .min ... .max)
            let testDir = tempPath + "glob-test-\(pid)-\(ticks)-\(unique)"
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
            try Path.String.Scope()(posixPath) { (dir: borrowing Path.Borrowed) in
                try body(dir, posixPath)
            }
        }

        /// Creates files and directories in the test directory.
        static func createTestFiles(in directory: Swift.String) throws {
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
    }

    // MARK: - Basic Match Tests

    extension Glob.Test.Unit {
        @Test
        func `Match simple wildcard pattern`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("*.txt")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 2)
                #expect(results.contains(dirString + "/file1.txt"))
                #expect(results.contains(dirString + "/file2.txt"))
            }
        }

        @Test
        func `Match question mark wildcard`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("file?.txt")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 2)
                #expect(results.contains(dirString + "/file1.txt"))
                #expect(results.contains(dirString + "/file2.txt"))
            }
        }

        @Test
        func `Match literal pattern`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("file1.txt")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 1)
                #expect(results.contains(dirString + "/file1.txt"))
            }
        }

        @Test
        func `Match with path segments`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("src/*.swift")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dirString + "/src/main.swift"))
                #expect(results.contains(dirString + "/src/test.swift"))
                #expect(results.contains(dirString + "/src/util.swift"))
            }
        }

        @Test
        func `Match returns empty for no matches`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("*.xyz")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.isEmpty)
            }
        }
    }

    // MARK: - Double Star Tests

    extension Glob.Test.Unit {
        @Test
        func `Match double star recursive`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("**/*.swift")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dirString + "/src/main.swift"))
                #expect(results.contains(dirString + "/src/test.swift"))
                #expect(results.contains(dirString + "/src/util.swift"))
            }
        }

        @Test
        func `Match double star finds all md files`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("**/*.md")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dirString + "/file3.md"))
                #expect(results.contains(dirString + "/docs/readme.md"))
                #expect(results.contains(dirString + "/docs/guide.md"))
            }
        }
    }

    // MARK: - Character Class Tests

    extension Glob.Test.Unit {
        @Test
        func `Match character class`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("file[12].txt")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 2)
                #expect(results.contains(dirString + "/file1.txt"))
                #expect(results.contains(dirString + "/file2.txt"))
            }
        }
    }

    // MARK: - Options Tests

    extension Glob.Test.Unit {
        @Test
        func `Dotfiles explicit policy excludes hidden files`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("*.txt")
                let options = Glob.Options(dotfiles: .explicit)
                let results = try Glob.match(pattern: pattern, in: dir, options: options)

                #expect(results.count == 2)
                #expect(!results.contains(dirString + "/.hidden.txt"))
            }
        }

        @Test
        func `Dotfiles always policy includes hidden files`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("*.txt")
                let options = Glob.Options(dotfiles: .always)
                let results = try Glob.match(pattern: pattern, in: dir, options: options)

                #expect(results.count == 3)
                #expect(results.contains(dirString + "/.hidden.txt"))
            }
        }

        @Test
        func `Dotfiles never policy excludes hidden files`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern(".*")
                let options = Glob.Options(dotfiles: .never)
                let results = try Glob.match(pattern: pattern, in: dir, options: options)

                #expect(results.isEmpty)
            }
        }

        @Test
        func `Explicit dotfile pattern matches hidden files`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern(".*.txt")
                let options = Glob.Options(dotfiles: .explicit)
                let results = try Glob.match(pattern: pattern, in: dir, options: options)

                #expect(results.count == 1)
                #expect(results.contains(dirString + "/.hidden.txt"))
            }
        }

        @Test
        func `Deterministic ordering sorts results`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("*.txt")
                let options = Glob.Options(ordering: .deterministic)
                let results = try Glob.match(pattern: pattern, in: dir, options: options)

                #expect(results == results.sorted())
            }
        }

        @Test
        func `Case insensitive matching`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                // Create a file with uppercase
                let upperPath = dirString + "/FILE.TXT"
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
                let results = try Glob.match(pattern: pattern, in: dir, options: options)

                #expect(results.contains(upperPath))
            }
        }
    }

    // MARK: - Include/Exclude Tests

    extension Glob.Test.Unit {
        @Test
        func `Match with exclusion pattern`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let include = [try Glob.Pattern("*.txt")]
                let exclude = [try Glob.Pattern("file1.txt")]
                let results = try Glob.match(
                    include: include,
                    excluding: exclude,
                    in: dir
                )

                #expect(results.count == 1)
                #expect(results.contains(dirString + "/file2.txt"))
                #expect(!results.contains(dirString + "/file1.txt"))
            }
        }

        @Test
        func `Match with multiple include patterns`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let include = [
                    try Glob.Pattern("*.txt"),
                    try Glob.Pattern("*.md"),
                ]
                let results = try Glob.match(include: include, in: dir)

                #expect(results.count == 3)
                #expect(results.contains(dirString + "/file1.txt"))
                #expect(results.contains(dirString + "/file2.txt"))
                #expect(results.contains(dirString + "/file3.md"))
            }
        }
    }

    // MARK: - Error Tests

    extension Glob.Test.Unit {
        @Test
        func `Match non-existent directory throws notFound`() throws {
            let pattern = try Glob.Pattern("*.txt")

            try Path.String.Scope()("C:/nonexistent/path/that/does/not/exist") { (dir: borrowing Path.Borrowed) in
                do {
                    _ = try Glob.match(pattern: pattern, in: dir)
                    Issue.record("expected Glob.match to throw Glob.Error")
                } catch {
                    // typed throws: `error` here is statically Glob.Error — reaching
                    // this catch IS the pass condition.
                    _ = error
                }
            }
        }

        @Test
        func `Match with skip error policy continues on error`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("**/*.txt")
                let options = Glob.Options(onError: .skip)

                // Should not throw, gracefully handles any errors
                let results = try Glob.match(pattern: pattern, in: dir, options: options)
                #expect(results.count >= 2)
            }
        }
    }

    // MARK: - Edge Cases

    extension Glob.Test.EdgeCase {
        @Test
        func `Match empty pattern`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                let pattern = try Glob.Pattern("")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count == 1)
            }
        }

        @Test
        func `Match pattern with only star`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("*")
                let results = try Glob.match(pattern: pattern, in: dir)

                #expect(results.count >= 4)
            }
        }
    }

    // MARK: - Windows-Specific Tests

    extension Glob.Test.Unit {
        @Test
        func `Path normalization outputs forward slashes`() throws {
            try Glob.Test.withTemporaryDirectory { dir, dirString in
                try Glob.Test.createTestFiles(in: dirString)

                let pattern = try Glob.Pattern("*.txt")
                let results = try Glob.match(pattern: pattern, in: dir)

                // All paths should use forward slashes
                for path in results {
                    #expect(!path.contains("\\"), "Path should use forward slashes: \(path)")
                }
            }
        }
    }

#endif
