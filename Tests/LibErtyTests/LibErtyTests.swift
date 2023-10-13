import XCTest
@testable import LibErty

final class LibErtyTests: XCTestCase {}

enum Console {
    case print(String)
    case readLn
}

func print(_ arg: String) -> Free<Console, Void> {.lift(.print(arg))}
func readLn() -> Free<Console, String> {.lift(.readLn)}

protocol ConsoleRunner : Runner where Meta == Console {
    mutating func runPrint(_ arg: String)
    func runReadLn() -> String
}

extension ConsoleRunner {
    mutating func runUnsafe(_ meta: Console) -> Any {
        switch meta {
        case .print(let string):
            runPrint(string)
        case .readLn:
            runReadLn()
        }
    }
}

func greet(_ name: String) -> String {"Hello, \(name)!"}
func identity<T>(_ arg: T) -> T {arg}

extension LibErtyTests {
    func testExample() async throws {
        
        let prog = print("What's your name?") |> readLn |> greet |> print
        
        let parsed = embed(prog, identity)
        
        struct MyRunner : ConsoleRunner {
            var console : [String] = []
            mutating func runPrint(_ arg: String) { console.append(arg) }
            func runReadLn() -> String { "Markus" }
        }
        
        var runner = MyRunner()
        try await runner.runUnsafe(parsed)
        
        
        XCTAssertEqual(runner.console, ["What's your name?", "Hello, Markus!"])
        
    }
}

// examples from https://www.haskellforall.com/2012/06/you-could-have-invented-free-monads.html

enum Toy {
    case print(String)
    case ringBell
}

func tPrint(_ arg: String) -> Free<Toy, Void> {.lift(.print(arg))}
func ringBell() -> Free<Toy, Void> {.lift(.ringBell)}

func showProg<T>(_ free: Free<Toy, T>) -> String {
    switch free.kind {
    case .pure(let t):
        "\(t)"
    case .free(let meta, let next):
        switch meta {
        case .print(let str):
            "print \"" + str + "\"\n" + showProg(next(()))
        case .ringBell:
            "ringBell \n" + showProg(next(()))
        }
    }
}

extension LibErtyTests {
    func testShowProg() {
        let prog = tPrint("Hello, World!") |> {.pure("What?")} |> tPrint |> ringBell
        Swift.print(showProg(prog))
        XCTAssert(!showProg(prog).isEmpty)
    }
}

enum Direction {
    case left, right, forward, backward, up, down
}

struct Image {}

enum Interaction {
    case look(Direction)
    case fire(Direction)
    case readLine
    case writeLine(String)
    case checkBreak
}

func look(_ dir: Direction) -> Free<Interaction, Image> { .lift(.look(dir)) }
func fire(_ dir: Direction) -> Free<Interaction, Void> { .lift(.fire(dir)) }
func readLine() -> Free<Interaction, String> { .lift(.readLine) }
func writeLine(_ str: String) -> Free<Interaction, Void> { .lift(.writeLine(str)) }
func checkBreak() -> Free<Interaction, Bool> { .lift(.checkBreak) }

protocol InteractionRunner : Runner where Meta == Interaction {
    mutating func runLook(_ dir: Direction) -> Image
    mutating func runFire(_ dir: Direction)
    mutating func runReadLine() async -> String
    mutating func runWriteLine(_ str: String)
    mutating func runCheckBreak() -> Bool
}

extension InteractionRunner {
    mutating func runUnsafe(_ meta: Interaction) async throws -> Any {
        switch meta {
        case .look(let direction):
            runLook(direction)
        case .fire(let direction):
            runFire(direction)
        case .readLine:
            await runReadLine()
        case .writeLine(let string):
            runWriteLine(string)
        case .checkBreak:
            runCheckBreak()
        }
    }
}

func easyToAnger() -> Free<Interaction, Void> {
    checkBreak() |> {brk in
        if brk {
            .pure(())
        }
        else {
            readLine() |> {line in
                if line == "No" {
                    fire(.forward) |> {writeLine("Take that!")} |> easyToAnger
                }
                else {
                    easyToAnger()
                }
            }
        }
    }
}

struct EasyToAngerRunner : InteractionRunner {
    var console : [String] = []
    func runLook(_ dir: Direction) -> Image {fatalError()}
    func runFire(_ dir: Direction) {}
    func runReadLine() async -> String {"No"}
    mutating func runWriteLine(_ str: String) {console.append(str)}
    func runCheckBreak() -> Bool {!console.isEmpty}
}

extension LibErtyTests {
    func testEasyToAnger() async throws {
        var runner = EasyToAngerRunner()
        try await runner.runUnsafe(easyToAnger())
        XCTAssertEqual(runner.console, ["Take that!"])
    }
}
