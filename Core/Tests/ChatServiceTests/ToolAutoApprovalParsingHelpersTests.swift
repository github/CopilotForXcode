import XCTest
@testable import ChatService

class ToolAutoApprovalParsingHelpersTests: XCTestCase {
    func testExtractSubCommandsWithTreeSitter() {
        // Simple command
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("git status"), ["git status"])
        
        // Chained commands
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("cd Core && swift test"), ["cd Core", "swift test"])
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("make build; make install"), ["make build", "make install"])
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("make build || echo 'fail'"), ["make build", "echo 'fail'"])

        // Pipes
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("ls -la | grep swift"), ["ls -la", "grep swift"])
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("ls &> out.txt"), ["ls &> out.txt"])

        // Complex with quotes (content inside quotes shouldn't be split)
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("echo 'hello && world'"), ["echo 'hello && world'"])
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("echo $(date +%Y) && ls"), ["echo $", "date +%Y", "ls"])

        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("git commit -m \"fix: update && clean\""), ["git commit -m \"fix: update && clean\""])
        
        // Nested / Subshells (might depend on how detailed the query is)
        // (command) query usually picks up the command nodes.
        // For `(cd Core; ls)`, the inner commands are commands too.
        XCTAssertEqual(Set(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("(cd Core; ls)")), Set(["cd Core", "ls"]))
        
        // Empty or whitespace
        XCTAssertEqual(ToolAutoApprovalManager.extractSubCommandsWithTreeSitter("   "), [])
    }
    
    func testExtractTerminalCommandNames() {
         XCTAssertEqual(ToolAutoApprovalManager.extractTerminalCommandNames(from: "git status"), ["git"])
         XCTAssertEqual(ToolAutoApprovalManager.extractTerminalCommandNames(from: "run_tests.sh --verbose"), ["run_tests.sh"])
         XCTAssertEqual(ToolAutoApprovalManager.extractTerminalCommandNames(from: "sudo apt-get install"), ["apt-get"])
         XCTAssertEqual(ToolAutoApprovalManager.extractTerminalCommandNames(from: "env VAR=1 command run"), ["command"])
         XCTAssertEqual(ToolAutoApprovalManager.extractTerminalCommandNames(from: "cd Core && swift test"), ["cd", "swift"])
         XCTAssertEqual(ToolAutoApprovalManager.extractTerminalCommandNames(from: "ls | grep match"), ["ls", "grep"])
        XCTAssertEqual(ToolAutoApprovalManager.extractTerminalCommandNames(from: "ls &> out.txt"), ["ls"])
    }
}
