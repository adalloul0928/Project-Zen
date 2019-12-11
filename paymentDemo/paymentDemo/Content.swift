protocol Content {
    var tag: String { get }
    var version: String { get }

    func format(level: Int) -> String
}

