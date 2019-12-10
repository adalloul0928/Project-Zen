let certificateTemplate = """
[
    $protocol: v2
    $timestamp: {timestamp}
    $account: {account}
    $publicKey: {publicKey}
](
    $type: /bali/notary/Certificate/v1
    $tag: {tag}
    $version: {version}
    $permissions: /bali/permissions/public/v1
    $previous: none
)
"""

class Certificate : Content {
    let timestamp = formatter.currentTimestamp()
    let account: String
    let publicKey: String
    let tag = formatter.generateTag()
    let version = "v1"

    init(account: String, publicKey: String) {
        self.account = account
        self.publicKey = publicKey
    }

    func format(level: Int) -> String {
        var certificate = certificateTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
        certificate = certificate.replacingOccurrences(of: "{account}", with: account)
        certificate = certificate.replacingOccurrences(of: "{publicKey}", with: publicKey)
        certificate = certificate.replacingOccurrences(of: "{tag}", with: tag)
        certificate = certificate.replacingOccurrences(of: "{version}", with: version)
        return formatter.indentLines(string: certificate, level: level)
    }

}

