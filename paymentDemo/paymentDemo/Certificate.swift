let certificateTemplate = """
[
    $publicKey: {publicKey}
    $algorithms: [
        $digest: "SHA512"
        $signature: "ED25519"
    ]
](
    $type: /bali/notary/Certificate/v1
    $tag: {tag}
    $version: {version}
    $permissions: /bali/permissions/public/v1
    $previous: none
)
"""

class Certificate : Content {
    let publicKey: String
    let tag = formatter.generateTag()
    let version = "v1"

    init(publicKey: String) {
        self.publicKey = publicKey
    }

    func format(level: Int) -> String {
        var certificate = certificateTemplate.replacingOccurrences(of: "{publicKey}", with: publicKey)
        certificate = certificate.replacingOccurrences(of: "{tag}", with: tag)
        certificate = certificate.replacingOccurrences(of: "{version}", with: version)
        return formatter.indentLines(string: certificate, level: level)
    }

}

