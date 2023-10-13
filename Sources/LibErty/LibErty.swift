
public struct Free<Meta, T> {
    
    public let kind : Kind
    
    public enum Kind {
        case pure(T)
        case free(Meta, (Any) -> Free<Meta, T>)
    }
    
    public static func pure(_ t: T) -> Self {
        .init(kind: .pure(t))
    }
    
    private static func free(_ meta: Meta, _ trafo: @escaping (Any) -> Free<Meta, T>) -> Self {
        .init(kind: .free(meta, trafo))
    }
    
}

public protocol Parser {
    associatedtype Source
    associatedtype Target
    func parse(_ meta: Source) -> Free<Target, Any>
}

public extension Parser {
    func translate<T>(_ prog: Free<Source, T>) -> Free<Target, T> {
        switch prog.kind {
        case .pure(let t):
            return .pure(t)
        case .free(let meta, let trafo):
            return parse(meta).flatMap{any in translate(trafo(any))}
        }
    }
}

public protocol Translator : Parser {
    associatedtype Source
    associatedtype Target
    func embed(_ meta: Source) -> Target
}

extension Translator {
    public func parse(_ meta: Source) -> Free<Target, Any> {
        .lift(embed(meta))
    }
}

public struct ClosureTranslator<Source, Target> : Translator {
    let closure : (Source) -> Target
    public init(_ closure: @escaping (Source) -> Target) {
        self.closure = closure
    }
    public func embed(_ meta: Source) -> Target {
        closure(meta)
    }
}

public func embed<Meta, NewMeta, T>(_ free: Free<Meta, T>,
                                    _ embedding: @escaping (Meta) -> NewMeta) -> Free<NewMeta, T> {
    ClosureTranslator(embedding).translate(free)
}

public func embed<Meta, NewMeta, S, T>(_ free: @escaping (S) -> Free<Meta, T>,
                                       _ embedding: @escaping (Meta) -> NewMeta) -> (S) -> Free<NewMeta, T> {
    {s in
        ClosureTranslator(embedding).translate(free(s))
    }
}

public func translate<P : Parser, T>(_ free: Free<P.Source, T>,
                                     _ parser: P) -> Free<P.Target, T> {
    parser.translate(free)
}


public func translate<P : Parser, S, T>(_ free: @escaping (S) -> Free<P.Source, T>,
                                     _ parser: P) -> (S) -> Free<P.Target, T> {
    {s in
        parser.translate(free(s))
    }
}

public protocol Runner {
    associatedtype Meta
    mutating func runUnsafe(_ meta: Meta) async throws -> Any
}

public extension Runner {
    mutating func runUnsafe<T>(_ prog: Free<Meta, T>) async throws -> T {
        var prog = prog
        while true {
            switch prog.kind {
            case .pure(let t):
                return t
            case .free(let meta, let trafo):
                prog = try await trafo(runUnsafe(meta))
            }
        }
    }
}

infix operator |> : AdditionPrecedence

public extension Free {
    static func lift(_ meta: Meta) -> Self {
        .free(meta) {any in .pure(any as! T)}
    }
    func erased() -> Free<Meta, Any> {
        flatMap{.pure($0)}
    }
    func map<U>(_ trafo: @escaping (T) -> U) -> Free<Meta, U> {
        flatMap{arg in .pure(trafo(arg))}
    }
    func flatMap<U>(_ trafo: @escaping (T) -> Free<Meta, U>) -> Free<Meta, U> {
        switch kind {
        case .pure(let t):
            return trafo(t)
        case .free(let free, let trf):
            return .free(free) {any in trf(any).flatMap(trafo)}
        }
    }
    static func |><U>(lhs: Self, rhs: @escaping (T) -> Free<Meta, U>) -> Free<Meta, U> {
        lhs.flatMap(rhs)
    }
    static func |><U>(lhs: Self, rhs: @escaping (T) -> U) -> Free<Meta, U> {
        lhs.map(rhs)
    }
}

public enum Either<S, T> {
    case either(S)
    case or(T)
}

public struct EitherParser<SP : Parser, TP : Parser> : Parser where SP.Target == TP.Target {
    let sParser : SP
    let tParser : TP
    public init(_ sParser: SP, _ tParser: TP) {
        self.sParser = sParser
        self.tParser = tParser
    }
    public func parse(_ meta: Either<SP.Source, TP.Source>) -> Free<SP.Target, Any> {
        switch meta {
        case .either(let s):
            sParser.parse(s)
        case .or(let t):
            tParser.parse(t)
        }
    }
}

public enum Either3<S1, S2, S3> {
    case case1(S1)
    case case2(S2)
    case case3(S3)
}

public struct Either3Parser<S1P : Parser, S2P : Parser, S3P : Parser> : Parser where S1P.Target == S2P.Target, S2P.Target == S3P.Target {
    let s1Parser : S1P
    let s2Parser : S2P
    let s3Parser : S3P
    public init(_ s1Parser: S1P, _ s2Parser: S2P, _ s3Parser: S3P) {
        self.s1Parser = s1Parser
        self.s2Parser = s2Parser
        self.s3Parser = s3Parser
    }
    public func parse(_ meta: Either3<S1P.Source, S2P.Source, S3P.Source>) -> Free<S1P.Target, Any> {
        switch meta {
        case .case1(let s1):
            s1Parser.parse(s1)
        case .case2(let s2):
            s2Parser.parse(s2)
        case .case3(let s3):
            s3Parser.parse(s3)
        }
    }
}

public enum Either4<S1, S2, S3, S4> {
    case case1(S1)
    case case2(S2)
    case case3(S3)
    case case4(S4)
}

public struct Either4Parser<S1P : Parser, S2P : Parser, S3P : Parser, S4P : Parser> : Parser where S1P.Target == S2P.Target, S2P.Target == S3P.Target, S3P.Target == S4P.Target {
    let s1Parser : S1P
    let s2Parser : S2P
    let s3Parser : S3P
    let s4Parser : S4P
    public init(_ s1Parser: S1P, _ s2Parser: S2P, _ s3Parser: S3P, _ s4Parser: S4P) {
        self.s1Parser = s1Parser
        self.s2Parser = s2Parser
        self.s3Parser = s3Parser
        self.s4Parser = s4Parser
    }
    public func parse(_ meta: Either4<S1P.Source, S2P.Source, S3P.Source, S4P.Source>) -> Free<S1P.Target, Any> {
        switch meta {
        case .case1(let s1):
            s1Parser.parse(s1)
        case .case2(let s2):
            s2Parser.parse(s2)
        case .case3(let s3):
            s3Parser.parse(s3)
        case .case4(let s4):
            s4Parser.parse(s4)
        }
    }
}

public enum Either5<S1, S2, S3, S4, S5> {
    case case1(S1)
    case case2(S2)
    case case3(S3)
    case case4(S4)
    case case5(S5)
}

public struct Either5Parser<S1P : Parser, S2P : Parser, S3P : Parser, S4P : Parser, S5P : Parser> : Parser where S1P.Target == S2P.Target, S2P.Target == S3P.Target, S3P.Target == S4P.Target, S4P.Target == S5P.Target {
    let s1Parser : S1P
    let s2Parser : S2P
    let s3Parser : S3P
    let s4Parser : S4P
    let s5Parser : S5P
    public init(_ s1Parser: S1P, _ s2Parser: S2P, _ s3Parser: S3P, _ s4Parser: S4P, _ s5Parser : S5P) {
        self.s1Parser = s1Parser
        self.s2Parser = s2Parser
        self.s3Parser = s3Parser
        self.s4Parser = s4Parser
        self.s5Parser = s5Parser
    }
    public func parse(_ meta: Either5<S1P.Source, S2P.Source, S3P.Source, S4P.Source, S5P.Source>) -> Free<S1P.Target, Any> {
        switch meta {
        case .case1(let s1):
            s1Parser.parse(s1)
        case .case2(let s2):
            s2Parser.parse(s2)
        case .case3(let s3):
            s3Parser.parse(s3)
        case .case4(let s4):
            s4Parser.parse(s4)
        case .case5(let s5):
            s5Parser.parse(s5)
        }
    }
}
