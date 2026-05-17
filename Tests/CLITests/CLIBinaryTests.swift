import XCTest

final class CLIBinaryTests: XCTestCase {

    private var binary: URL? {
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            "\(cwd)/.build/debug/macoswheels",
            "\(cwd)/.build/release/macoswheels",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func run(_ args: String...) throws -> (stdout: String, stderr: String, code: Int32) {
        guard let bin = binary else {
            throw XCTSkip("CLI binary not built; run swift build first")
        }
        let p = Process()
        p.executableURL = bin
        p.arguments = args
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (out, err, p.terminationStatus)
    }

    func testVersion() throws {
        let r = try run("--version")
        XCTAssertEqual(r.code, 0)
        XCTAssertTrue(r.stdout.hasPrefix("macoswheels "), "got: \(r.stdout)")
    }

    func testHelp() throws {
        let r = try run("--help")
        XCTAssertEqual(r.code, 0)
        XCTAssertTrue(r.stdout.contains("dump-effect"))
    }

    func testUnknownSubcommandExitCode2() throws {
        let r = try run("totally-not-a-subcommand")
        XCTAssertEqual(r.code, 2)
    }

    func testListShowsKnownWheels() throws {
        let r = try run("list")
        XCTAssertEqual(r.code, 0)
        XCTAssertTrue(r.stdout.contains("Thrustmaster T150"))
        XCTAssertTrue(r.stdout.contains("Logitech G29"))
    }

    func testDumpEffectConstantT150() throws {
        let r = try run("dump-effect", "constant", "--magnitude", "16384")
        XCTAssertEqual(r.code, 0)
        XCTAssertTrue(r.stdout.contains("wheel=T150 effect=constant"))
        XCTAssertTrue(r.stdout.contains("EP 0x02"))
    }

    func testDumpEffectSpringG29() throws {
        let r = try run("dump-effect", "spring", "--wheel", "G29", "--magnitude", "16384")
        XCTAssertEqual(r.code, 0)
        XCTAssertTrue(r.stdout.contains("wheel=G29 effect=spring"))
        XCTAssertTrue(r.stdout.contains("EP 0x01"))
    }

    func testDumpEffectUnknownEffectKindExits2() throws {
        let r = try run("dump-effect", "definitely-not-a-thing")
        XCTAssertEqual(r.code, 2)
    }

    func testDumpEffectUnknownWheelErrors() throws {
        let r = try run("dump-effect", "constant", "--wheel", "Frobnicator9000")
        XCTAssertNotEqual(r.code, 0)
    }

    func testRangeOutOfBoundsExits2() throws {
        let r = try run("range", "50")
        XCTAssertEqual(r.code, 2)
        XCTAssertTrue(r.stderr.contains("out of bounds"))
    }
}
