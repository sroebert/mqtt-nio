@resultBuilder
struct ArrayBuilder<Value> {
    typealias Component = [Value]
    
    enum EmptyExpression {
        case none
    }
    
    static func buildBlock(_ components: Component...) -> Component {
        return components.flatMap { $0 }
    }
    
    static func buildExpression(_ value: Value) -> Component {
        return [value]
    }
    
    static func buildExpression(_ value: EmptyExpression) -> Component {
        return []
    }

    static func buildOptional(_ component: Component?) -> Component {
        return component ?? []
    }
    
    static func buildEither(first: Component) -> Component {
        return first
    }
    
    static func buildEither(second: Component) -> Component {
        return second
    }
    
    static func buildArray(_ components: [Component]) -> Component {
        return components.flatMap { $0 }
    }
    
    static func buildLimitedAvailability(_ component: Component) -> Component {
        return component
    }
}
