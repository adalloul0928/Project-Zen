let citationTemplate = """
[
    $protocol: v2
    $timestamp: {timestamp}
    $tag: {tag}
    $version: {version}
    $digest: '{digest}
    '
]($type: /bali/notary/Citation/v1)
"""

class Citation {
    let timestamp = formatter.currentTimestamp()
    let tag: String
    let version: String
    let digest: String

    init(tag: String, version: String, digest: String) {
        self.tag = tag
        self.version = version
        self.digest = digest
    }

    func format(level: Int) -> String {
        var citation = citationTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
        citation = citation.replacingOccurrences(of: "{tag}", with: tag)
        citation = citation.replacingOccurrences(of: "{version}", with: version)
        citation = citation.replacingOccurrences(of: "{digest}", with: formatter.indentLines(string: digest, level: 2))
        return formatter.indentLines(string: citation, level: level)
    }

}

