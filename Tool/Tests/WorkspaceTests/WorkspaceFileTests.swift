import XCTest
import Foundation
@testable import Workspace

class WorkspaceFileTests: XCTestCase {
    func testMatchesPatterns() {
        let url1 = URL(fileURLWithPath: "/path/to/file.swift")
        let url2 = URL(fileURLWithPath: "/path/to/.git")
        let patterns = [".git", ".svn"]

        XCTAssertTrue(WorkspaceFile.matchesPatterns(url2, patterns: patterns))
        XCTAssertFalse(WorkspaceFile.matchesPatterns(url1, patterns: patterns))
    }

    func testIsXCWorkspace() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        do {
            let xcworkspaceURL = try createSubdirectory(in: tmpDir, withName: "myWorkspace.xcworkspace")
            XCTAssertFalse(WorkspaceFile.isXCWorkspace(xcworkspaceURL))
            let xcworkspaceDataURL = try createFile(in: xcworkspaceURL, withName: "contents.xcworkspacedata", contents: "")
            XCTAssertTrue(WorkspaceFile.isXCWorkspace(xcworkspaceURL))
        } catch {
            throw error
        }
    }

    func testIsXCProject() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        do {
            let xcprojectURL = try createSubdirectory(in: tmpDir, withName: "myProject.xcodeproj")
            XCTAssertFalse(WorkspaceFile.isXCProject(xcprojectURL))
            let xcprojectDataURL = try createFile(in: xcprojectURL, withName: "project.pbxproj", contents: "")
            XCTAssertTrue(WorkspaceFile.isXCProject(xcprojectURL))
        } catch {
            throw error
        }
    }

    func testGetFilesInActiveProject() throws {
        let tmpDir = try createTemporaryDirectory()
        do {
            let xcprojectURL = try createXCProjectFolder(in: tmpDir, withName: "myProject.xcodeproj")
            _ = try createFile(in: tmpDir, withName: "file1.swift", contents: "")
            _ = try createFile(in: tmpDir, withName: "file2.swift", contents: "")
            _ = try createSubdirectory(in: tmpDir, withName: ".git")
            let files = WorkspaceFile.getFilesInActiveWorkspace(workspaceURL: xcprojectURL, workspaceRootURL: tmpDir)
            let fileNames = files.map { $0.url.lastPathComponent }
            XCTAssertEqual(files.count, 2)
            XCTAssertTrue(fileNames.contains("file1.swift"))
            XCTAssertTrue(fileNames.contains("file2.swift"))
        } catch {
            deleteDirectoryIfExists(at: tmpDir)
            throw error
        }
        deleteDirectoryIfExists(at: tmpDir)
    }

    func testGetFilesInActiveWorkspace() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        do {
            let myWorkspaceRoot = try createSubdirectory(in: tmpDir, withName: "myWorkspace")
            let xcWorkspaceURL = try createXCWorkspaceFolder(in: myWorkspaceRoot, withName: "myWorkspace.xcworkspace", fileRefs: [
                "container:myProject.xcodeproj",
                "group:../notExistedDir/notExistedProject.xcodeproj",
                "group:../myDependency",])
            let xcprojectURL = try createXCProjectFolder(in: myWorkspaceRoot, withName: "myProject.xcodeproj")
            let myDependencyURL = try createSubdirectory(in: tmpDir, withName: "myDependency")

            // Files under workspace should be included
            _ = try createFile(in: myWorkspaceRoot, withName: "file1.swift", contents: "")
            // unsupported patterns and file extension should be excluded
            _ = try createFile(in: myWorkspaceRoot, withName: "unsupportedFileExtension.xyz", contents: "")
            _ = try createSubdirectory(in: myWorkspaceRoot, withName: ".git")

            // Files under project metadata folder should be excluded
            _ = try createFile(in: xcprojectURL, withName: "fileUnderProjectMetadata.swift", contents: "")

            // Files under dependency should be included
            _ = try createFile(in: myDependencyURL, withName: "depFile1.swift", contents: "")
            // Should be excluded
            _ = try createSubdirectory(in: myDependencyURL, withName: ".git")

            // Files under unrelated directories should be excluded
            _ = try createFile(in: tmpDir, withName: "unrelatedFile1.swift", contents: "")

            let files = WorkspaceFile.getFilesInActiveWorkspace(workspaceURL: xcWorkspaceURL, workspaceRootURL: myWorkspaceRoot)
            let fileNames = files.map { $0.url.lastPathComponent }
            XCTAssertEqual(files.count, 2)
            XCTAssertTrue(fileNames.contains("file1.swift"))
            XCTAssertTrue(fileNames.contains("depFile1.swift"))
        } catch {
            throw error
        }
    }

    func testGetSubprojectURLsFromXCWorkspace() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }

        let workspaceDir = try createSubdirectory(in: tmpDir, withName: "workspace")

        // Create tryapp directory and project
        let tryappDir = try createSubdirectory(in: tmpDir, withName: "tryapp")
        _ = try createXCProjectFolder(in: tryappDir, withName: "tryapp.xcodeproj")

        // Create Copilot for Xcode project
        _ = try createXCProjectFolder(in: workspaceDir, withName: "Copilot for Xcode.xcodeproj")

        // Create Test1 directory
        let test1Dir = try createSubdirectory(in: tmpDir, withName: "Test1")

        // Create Test2 directory and project
        let test2Dir = try createSubdirectory(in: tmpDir, withName: "Test2")
        _ = try createXCProjectFolder(in: test2Dir, withName: "project2.xcodeproj")

        // Create the workspace data file with our references
        let xcworkspaceData = """
        <?xml version="1.0" encoding="UTF-8"?>
           <Workspace
              version = "1.0">
              <FileRef
                 location = "container:../tryapp/tryapp.xcodeproj">
              </FileRef>
              <FileRef
                 location = "group:Copilot for Xcode.xcodeproj">
              </FileRef>
              <FileRef
                 location = "group:../Test1">
              </FileRef>
              <FileRef
                 location = "group:../Test2/project2.xcodeproj">
              </FileRef>
              <FileRef
                 location = "absolute:/Test3/project3">
              </FileRef>
           </Workspace>
        """
        let workspaceURL = try createXCWorkspaceFolder(in: workspaceDir, withName: "workspace.xcworkspace", xcworkspacedata: xcworkspaceData)

        let subprojectURLs = WorkspaceFile.getSubprojectURLs(in: workspaceURL)

        XCTAssertEqual(subprojectURLs.count, 4)
        let resolvedPaths = subprojectURLs.map { $0.path }
        let expectedPaths = [
            tryappDir.path,
            workspaceDir.path, // For Copilot for Xcode.xcodeproj
            test1Dir.path,
            test2Dir.path
        ]
        XCTAssertEqual(resolvedPaths, expectedPaths)
    }

    func testGetSubprojectURLsFromEmbeddedXCWorkspace() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }

        // Create the workspace data file with a self reference
        let xcworkspaceData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace
           version = "1.0">
           <FileRef
              location = "self:">
           </FileRef>
        </Workspace>
        """

        // Create the MyApp directory structure
        let myAppDir = try createSubdirectory(in: tmpDir, withName: "MyApp")
        let xcodeProjectDir = try createXCProjectFolder(in: myAppDir, withName: "MyApp.xcodeproj")
        let embeddedWorkspaceDir = try createXCWorkspaceFolder(in: xcodeProjectDir, withName: "MyApp.xcworkspace", xcworkspacedata: xcworkspaceData)

        let subprojectURLs = WorkspaceFile.getSubprojectURLs(in: embeddedWorkspaceDir)
        XCTAssertEqual(subprojectURLs.count, 1)
        XCTAssertEqual(subprojectURLs[0].lastPathComponent, "MyApp")
        XCTAssertEqual(subprojectURLs[0].path, myAppDir.path)
    }

    func testGetSubprojectURLsFromXCWorkspaceOrganizedByGroup() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }

        // Create directories for the projects and groups
        let tryappDir = try createSubdirectory(in: tmpDir, withName: "tryapp")
        _ = try createXCProjectFolder(in: tryappDir, withName: "tryapp.xcodeproj")

        let webLibraryDir = try createSubdirectory(in: tmpDir, withName: "WebLibrary")

        // Create the group directories
        let group1Dir = try createSubdirectory(in: tmpDir, withName: "group1")
        let group2Dir = try createSubdirectory(in: group1Dir, withName: "group2")
        _ = try createSubdirectory(in: group2Dir, withName: "group3")
        _ = try createSubdirectory(in: group1Dir, withName: "group4")

        // Create the MyProjects directory
        let myProjectsDir = try createSubdirectory(in: tmpDir, withName: "MyProjects")

        // Create the copilot-xcode directory and project
        let copilotXcodeDir = try createSubdirectory(in: myProjectsDir, withName: "copilot-xcode")
        _ = try createXCProjectFolder(in: copilotXcodeDir, withName: "Copilot for Xcode.xcodeproj")

        // Create the SwiftLanguageWeather directory and project
        let swiftWeatherDir = try createSubdirectory(in: myProjectsDir, withName: "SwiftLanguageWeather")
        _ = try createXCProjectFolder(in: swiftWeatherDir, withName: "SwiftWeather.xcodeproj")

        // Create the workspace data file with a complex group structure
        let xcworkspaceData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace
           version = "1.0">
           <FileRef
              location = "container:tryapp/tryapp.xcodeproj">
           </FileRef>
           <FileRef
              location = "group:WebLibrary">
           </FileRef>
           <Group
              location = "group:group1"
              name = "group1">
              <Group
                 location = "group:group2"
                 name = "group2">
                  <Group
                     location = "group:group3"
                     name = "group3">
                     <FileRef
                        location = "group:../../../MyProjects/copilot-xcode/Copilot for Xcode.xcodeproj">
                     </FileRef>
                  </Group>
              </Group>
              <Group
                 location = "group:group4"
                 name = "group4">
              </Group>
              <FileRef
                 location = "group:../MyProjects/SwiftLanguageWeather/SwiftWeather.xcodeproj">
              </FileRef>
           </Group>
        </Workspace>
        """

        // Create a test workspace structure
        let workspaceURL = try createXCWorkspaceFolder(in: tmpDir, withName: "workspace.xcworkspace", xcworkspacedata: xcworkspaceData)

        let subprojectURLs = WorkspaceFile.getSubprojectURLs(in: workspaceURL)
        XCTAssertEqual(subprojectURLs.count, 4)
        let expectedPaths = [
            tryappDir.path,
            webLibraryDir.path,
            copilotXcodeDir.path,
            swiftWeatherDir.path
        ]
        for expectedPath in expectedPaths {
            XCTAssertTrue(subprojectURLs.contains { $0.path == expectedPath }, "Expected path not found: \(expectedPath)")
        }
    }

    func deleteDirectoryIfExists(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to delete directory at \(url.path)")
            }
        }
    }

    func createTemporaryDirectory() throws -> URL {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let directoryName = UUID().uuidString
        let directoryURL = temporaryDirectoryURL.appendingPathComponent(directoryName)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        #if DEBUG
        print("Create temp directory \(directoryURL.path)")
        #endif
        return directoryURL
    }

    func createSubdirectory(in directory: URL, withName name: String) throws -> URL {
        let subdirectoryURL = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return subdirectoryURL
    }

    func createFile(in directory: URL, withName name: String, contents: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        let data = contents.data(using: .utf8)
        FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: nil)
        return fileURL
    }
        
    func createXCProjectFolder(in baseDirectory: URL, withName projectName: String) throws -> URL {
        let projectURL = try createSubdirectory(in: baseDirectory, withName: projectName)
        if projectName.hasSuffix(".xcodeproj") {
            _ = try createFile(in: projectURL, withName: "project.pbxproj", contents: "// Project file contents")
        }
        return projectURL
    }

    func createXCWorkspaceFolder(in baseDirectory: URL, withName workspaceName: String, fileRefs: [String]?) throws -> URL {
        let xcworkspaceURL = try createSubdirectory(in: baseDirectory, withName: workspaceName)
        if let fileRefs {
            _ = try createXCworkspacedataFile(directory: xcworkspaceURL, fileRefs: fileRefs)
        }
        return xcworkspaceURL
    }

    func createXCWorkspaceFolder(in baseDirectory: URL, withName workspaceName: String, xcworkspacedata: String) throws -> URL {
        let xcworkspaceURL = try createSubdirectory(in: baseDirectory, withName: workspaceName)
        _ = try createFile(in: xcworkspaceURL, withName: "contents.xcworkspacedata", contents: xcworkspacedata)
        return xcworkspaceURL
    }

    func createXCworkspacedataFile(directory: URL, fileRefs: [String]) throws -> URL {
        let contents = generateXCWorkspacedataContents(fileRefs: fileRefs)
        return try createFile(in: directory, withName: "contents.xcworkspacedata", contents: contents)
    }

    func generateXCWorkspacedataContents(fileRefs: [String]) -> String {
        var contents = """
        <?xml version="1.0" encoding="UTF-8"?>
           <Workspace
              version = "1.0">
        """
        for fileRef in fileRefs {
            contents += """
                <FileRef
                     location = "\(fileRef)">
                </FileRef>
            """
        }
        contents += "</Workspace>"
        return contents
    }
    
    func testIsValidFile() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        do {
            // Test valid Swift file
            let swiftFileURL = try createFile(in: tmpDir, withName: "ValidFile.swift", contents: "// Swift code")
            XCTAssertTrue(try WorkspaceFile.isValidFile(swiftFileURL))
            
            // Test valid files with different supported extensions
            let jsFileURL = try createFile(in: tmpDir, withName: "script.js", contents: "// JavaScript")
            XCTAssertTrue(try WorkspaceFile.isValidFile(jsFileURL))
            
            let mdFileURL = try createFile(in: tmpDir, withName: "README.md", contents: "# Markdown")
            XCTAssertTrue(try WorkspaceFile.isValidFile(mdFileURL))
            
            let jsonFileURL = try createFile(in: tmpDir, withName: "config.json", contents: "{}")
            XCTAssertTrue(try WorkspaceFile.isValidFile(jsonFileURL))
            
            // Test case insensitive extension matching
            let swiftUpperURL = try createFile(in: tmpDir, withName: "File.SWIFT", contents: "// Swift")
            XCTAssertTrue(try WorkspaceFile.isValidFile(swiftUpperURL))
            
            // Test unsupported file extension
            let unsupportedFileURL = try createFile(in: tmpDir, withName: "file.xyz", contents: "unsupported")
            XCTAssertFalse(try WorkspaceFile.isValidFile(unsupportedFileURL))
            
            // Test files matching skip patterns
            let gitFileURL = try createFile(in: tmpDir, withName: ".git", contents: "")
            XCTAssertFalse(try WorkspaceFile.isValidFile(gitFileURL))
            
            let dsStoreURL = try createFile(in: tmpDir, withName: ".DS_Store", contents: "")
            XCTAssertFalse(try WorkspaceFile.isValidFile(dsStoreURL))
            
            let nodeModulesURL = try createFile(in: tmpDir, withName: "node_modules", contents: "")
            XCTAssertFalse(try WorkspaceFile.isValidFile(nodeModulesURL))
            
            // Test directory (should return false)
            let subdirURL = try createSubdirectory(in: tmpDir, withName: "subdir")
            XCTAssertFalse(try WorkspaceFile.isValidFile(subdirURL))
            
            // Test Xcode workspace (should return false)
            let xcworkspaceURL = try createSubdirectory(in: tmpDir, withName: "test.xcworkspace")
            _ = try createFile(in: xcworkspaceURL, withName: "contents.xcworkspacedata", contents: "")
            XCTAssertFalse(try WorkspaceFile.isValidFile(xcworkspaceURL))
            
            // Test Xcode project (should return false)
            let xcprojectURL = try createSubdirectory(in: tmpDir, withName: "test.xcodeproj")
            _ = try createFile(in: xcprojectURL, withName: "project.pbxproj", contents: "")
            XCTAssertFalse(try WorkspaceFile.isValidFile(xcprojectURL))
            
        } catch {
            throw error
        }
    }
    
    func testIsValidFileWithCustomExclusionFilter() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        do {
            let swiftFileURL = try createFile(in: tmpDir, withName: "TestFile.swift", contents: "// Swift code")
            let jsFileURL = try createFile(in: tmpDir, withName: "script.js", contents: "// JavaScript")
            
            // Test without custom exclusion filter
            XCTAssertTrue(try WorkspaceFile.isValidFile(swiftFileURL))
            XCTAssertTrue(try WorkspaceFile.isValidFile(jsFileURL))
            
            // Test with custom exclusion filter that excludes Swift files
            let excludeSwiftFilter: (URL) -> Bool = { url in
                return url.pathExtension.lowercased() == "swift"
            }
            
            XCTAssertFalse(try WorkspaceFile.isValidFile(swiftFileURL, shouldExcludeFile: excludeSwiftFilter))
            XCTAssertTrue(try WorkspaceFile.isValidFile(jsFileURL, shouldExcludeFile: excludeSwiftFilter))
            
            // Test with custom exclusion filter that excludes files with "Test" in name
            let excludeTestFilter: (URL) -> Bool = { url in
                return url.lastPathComponent.contains("Test")
            }
            
            XCTAssertFalse(try WorkspaceFile.isValidFile(swiftFileURL, shouldExcludeFile: excludeTestFilter))
            XCTAssertTrue(try WorkspaceFile.isValidFile(jsFileURL, shouldExcludeFile: excludeTestFilter))
            
        } catch {
            throw error
        }
    }
    
    func testIsValidFileWithAllSupportedExtensions() throws {
        let tmpDir = try createTemporaryDirectory()
        defer {
            deleteDirectoryIfExists(at: tmpDir)
        }
        do {
            let supportedExtensions = supportedFileExtensions
            
            for (index, ext) in supportedExtensions.enumerated() {
                let fileName = "testfile\(index).\(ext)"
                let fileURL = try createFile(in: tmpDir, withName: fileName, contents: "test content")
                XCTAssertTrue(try WorkspaceFile.isValidFile(fileURL), "File with extension .\(ext) should be valid")
            }
            
        } catch {
            throw error
        }
    }
}
