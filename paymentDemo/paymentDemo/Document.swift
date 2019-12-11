let documentTemplate = """
[
    $protocol: v2
    $timestamp: {timestamp}
    $account: {account}
    $content: {content}
    $certificate: {certificate}
]($type: /bali/notary/Document/v1)
"""

let signedTemplate = """
[
    $protocol: v2
    $timestamp: {timestamp}
    $account: {account}
    $content: {content}
    $certificate: {certificate}
    $signature: '{signature}
    '
]($type: /bali/notary/Document/v1)
"""

class Document {
    let timestamp = formatter.currentTimestamp()
    let account: String
    let content: Content
    let certificate: Citation?
    let signature: String?

    init(account: String, content: Content, certificate: Citation? = nil, signature: String? = nil) {
        self.account = account
        self.content = content
        self.certificate = certificate
        self.signature = signature
    }

    func format(level: Int) -> String {
        var document: String
        if signature != nil {
            document = signedTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
            document = document.replacingOccurrences(of: "{signature}", with: formatter.indentLines(string: signature!, level: 2))
        } else {
            document = documentTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
        }
        document = document.replacingOccurrences(of: "{account}", with: account)
        document = document.replacingOccurrences(of: "{content}", with: content.format(level: level + 1))
        if certificate != nil {
            document = document.replacingOccurrences(of: "{certificate}", with: certificate!.format(level: level + 1))
        } else {
            document = document.replacingOccurrences(of: "{certificate}", with: "none")
        }
        return formatter.indentLines(string: document, level: level)
    }

}
