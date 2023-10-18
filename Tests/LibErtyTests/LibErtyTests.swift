import XCTest
@testable import LibErty

final class LibErtyTests: XCTestCase {}

protocol Print {
    static func print(_ arg: String) -> Self
}
protocol ReadLn {
    static var readLn : Self {get}
}

typealias Console = Print & ReadLn

enum MyConsole : Console {
    case print(String)
    case readLn
}

func print<C : Print>(_ arg: String) -> Free<C, Void> {.lift(.print(arg))}
func readLn<C : ReadLn>() -> Free<C, String> {.lift(.readLn)}

protocol ConsoleRunner {
    mutating func runPrint(_ arg: String) async throws
    mutating func runReadLn() async throws -> String
}

func greet(_ name: String) -> String {"Hello, \(name)!"}

extension LibErtyTests {
    func testExample() {
        
        let prog : Free<MyConsole, Void> = print("What's your name?") |> readLn |> greet |> print
        
        struct MyRunner : ConsoleRunner {
            
            var console : [String] = []
            
            mutating func runPrint(_ arg: String) { console.append(arg) }
            func runReadLn() -> String { "Markus" }
            
            mutating func runProg<T>(_ free: Free<MyConsole, T>) -> T {
                switch free.kind {
                case .pure(let t):
                    t
                case .free(let meta, let then):
                    switch meta {
                    case .print(let string):
                        runProg(then(runPrint(string)))
                    case .readLn:
                        runProg(then(runReadLn()))
                    }
                }
            }
            
        }
        
        var runner = MyRunner()
        runner.runProg(prog)
        
        
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
    mutating func runCommand(_ meta: Interaction) async throws -> Any {
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
        try await runner.runProg(easyToAnger())
        XCTAssertEqual(runner.console, ["Take that!"])
    }
}


enum Failure {
    case fail(Error)
}

func fail<T>(_ error: Error) -> Free<Failure, T> {.lift(.fail(error))}

struct DivisionByZero : Error {}

func failableDivision(_ a: Int, _ b: Int) -> Free<Failure, Int> {
    guard b != 0 else {return fail(DivisionByZero())}
    return .pure(a/b)
}

func toResult<T>(_ free: Free<Failure, T>) -> Result<T, Error> {
    switch free.kind {
    case .pure(let t):
            .success(t)
    case .free(let meta, _):
        switch meta {
        case .fail(let error):
                .failure(error)
        }
    }
}


protocol DeepThought {
    static func query(_ arg: String) -> Self
}

func query<DT : DeepThought>(_ arg: String) -> Free<DT, String> {.lift(.query(arg))}

protocol ThoughtRunner {
    mutating func runQuery(_ question: String) async throws -> String
}

func think<DT : DeepThought>(_ question: String) -> Free<DT, String> {
    if question == "What is the answer to life, the universe and everything?" {
        query(question) |> {answer in
            answer == "42" ? .pure(answer) : think(question)
        }
    }
    else {
        query(question)
    }
}

func consoleThought<DT : Console & DeepThought>() -> Free<DT, Void> {
    print("Your question to Deep Thought:") |> readLn |> think |> print
}

enum MyThought : Console, DeepThought {
    case print(String)
    case readLn
    case query(String)
}

extension LibErtyTests {
    
    func testDeepThought() {
        
        let thought : Free<MyThought, Void> = consoleThought()
        
        struct MyThoughtRunner : ConsoleRunner, ThoughtRunner {
            
            var console : [String] = []
            
            mutating func runPrint(_ arg: String) { console.append(arg) }
            func runReadLn() -> String { "What is the answer to life, the universe and everything?" }
            func runQuery(_ question: String) -> String { "42" }
        
            mutating func runThought<T>(_ thought: Free<MyThought, T>) -> T {
                switch thought.kind {
                case .pure(let t):
                    t
                case .free(let meta, let then):
                    switch meta {
                    case .print(let line):
                        runThought(then(runPrint(line)))
                    case .readLn:
                        runThought(then(runReadLn()))
                    case .query(let question):
                        runThought(then(runQuery(question)))
                    }
                }
            }
            
        }
        
        var runner = MyThoughtRunner()
        runner.runThought(thought)
        
        XCTAssertEqual(["Your question to Deep Thought:", "42"], runner.console)
        
    }
    
}

protocol RecorderCmd {
    static var startRecording : Self {get}
    static var stopRecording : Self {get}
    static var getIsRecording : Self {get}
}

func startRecording<R : RecorderCmd>() -> Free<R, Void> {.lift(.startRecording)}
func stopRecording<R : RecorderCmd>() -> Free<R, Void> {.lift(.stopRecording)}
func getIsRecording<R : RecorderCmd>() -> Free<R, Bool> {.lift(.getIsRecording)}

protocol RecorderRunner {
    mutating func doStartRecording() async throws
    mutating func doStopRecording() async throws
    mutating func doGetIsRecording() async throws -> Bool
}

protocol RecorderSchedule {
    static var getShouldBeRecording : Self {get}
}

func getShouldBeRecording<R : RecorderSchedule>() -> Free<R, Bool> {.lift(.getShouldBeRecording)}

protocol RecorderScheduleRunner {
    mutating func doGetShouldBeRecording() async throws -> Bool
}

func onRecorderEvent<R : RecorderCmd & RecorderSchedule>() -> Free<R, Void> {
    getShouldBeRecording() |> {shouldBeRecording in
        getIsRecording() |> {isRecording in
            if isRecording == shouldBeRecording { .pure(()) }
            else if shouldBeRecording { startRecording() }
            else { stopRecording() }
        }
    }
}

enum TestRecorderCmd : RecorderCmd, RecorderSchedule {
    case startRecording
    case stopRecording
    case getIsRecording
    case getShouldBeRecording
}

struct TestRecorderRunner : RecorderRunner {
    
    var shouldBeRecording = false
    var isRecording = false
    
    mutating func doStartRecording() {
        isRecording = true
    }
    mutating func doStopRecording() {
        isRecording = false
    }
    func doGetIsRecording() -> Bool {
        isRecording
    }
    mutating func doRecord<T>(_ free: Free<TestRecorderCmd, T>) -> T {
        switch free.kind {
        case .pure(let t):
            t
        case .free(let meta, let then):
            switch meta {
            case .startRecording:
                doRecord(then(doStartRecording()))
            case .stopRecording:
                doRecord(then(doStopRecording()))
            case .getIsRecording:
                doRecord(then(doGetIsRecording()))
            case .getShouldBeRecording:
                doRecord(then(shouldBeRecording))
            }
        }
    }
}

extension LibErtyTests {
    func testRecorder() {
        
        var recorder = TestRecorderRunner()
        
        for _ in 0..<100 {
            recorder.shouldBeRecording = .random()
            recorder.doRecord(onRecorderEvent())
            XCTAssertEqual(recorder.isRecording, recorder.shouldBeRecording)
        }
        
    }
}
