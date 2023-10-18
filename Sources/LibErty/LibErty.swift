
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

func |><S, T>(lhs: S, rhs: @escaping (S) -> T) -> T {
    rhs(lhs)
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

public protocol Runner {
    associatedtype Meta
    mutating func runCommand(_ meta: Meta) async throws -> Any
}

public extension Runner {
    mutating func runProg<T>(_ prog: Free<Meta, T>) async throws -> T {
        var prog = prog
        while true {
            switch prog.kind {
            case .pure(let t):
                return t
            case .free(let meta, let trafo):
                prog = try await trafo(runCommand(meta))
            }
        }
    }
}
