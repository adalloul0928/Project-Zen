
func generateCertificate(
    accountTag: String,
    publicKey: String,
    documentTag: String,
    documentVersion: String
) -> String {
    let timestamp = currentTimestamp()
    var certificate = certificateTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
    certificate = certificate.replacingOccurrences(of: "{accountTag}", with: accountTag)
    certificate = certificate.replacingOccurrences(of: "{publicKey}", with: publicKey)
    certificate = certificate.replacingOccurrences(of: "{documentTag}", with: documentTag)
    certificate = certificate.replacingOccurrences(of: "{documentVersion}", with: documentVersion)
    return certificate
}

func generateTransaction(
    transactionTag: String,
    date: String,
    time: String,
    merchant: String,
    amount: String,
    documentTag: String,
    documentVersion: String
) -> String {
    var transaction = transactionTemplate.replacingOccurrences(of: "{transactionTag}", with: transactionTag)
    transaction = transaction.replacingOccurrences(of: "{date}", with: date)
    transaction = transaction.replacingOccurrences(of: "{time}", with: time)
    transaction = transaction.replacingOccurrences(of: "{merchant}", with: merchant)
    transaction = transaction.replacingOccurrences(of: "{amount}", with: amount)
    transaction = transaction.replacingOccurrences(of: "{documentTag}", with: documentTag)
    transaction = transaction.replacingOccurrences(of: "{documentVersion}", with: documentVersion)
    return transaction
}

func generateCitation(documentTag: String, documentVersion: String, digest: String) -> String {
    let timestamp = currentTimestamp()
    var citation = citationTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
    citation = citation.replacingOccurrences(of: "{documentTag}", with: documentTag)
    citation = citation.replacingOccurrences(of: "{documentVersion}", with: documentVersion)
    citation = citation.replacingOccurrences(of: "{digest}", with: indentLines(string: digest, level: 2))
    return citation
}

func generateDocument(timestamp: String, accountTag: String, content: String, citation: String) -> String {
    var document = documentTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
    document = document.replacingOccurrences(of: "{accountTag}", with: accountTag)
    document = document.replacingOccurrences(of: "{content}", with: indentLines(string: content, level: 1))
    document = document.replacingOccurrences(of: "{citation}", with: indentLines(string: citation, level: 1))
    return document
}

func generateSignedDocument(timestamp: String, accountTag: String, content: String, citation: String, signature: String) -> String {
    var document = signedTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
    document = document.replacingOccurrences(of: "{accountTag}", with: accountTag)
    document = document.replacingOccurrences(of: "{content}", with: indentLines(string: content, level: 1))
    document = document.replacingOccurrences(of: "{citation}", with: indentLines(string: citation, level: 1))
    document = document.replacingOccurrences(of: "{signature}", with: indentLines(string: signature, level: 2))
    return document
}

/* TEST IT OUT*/

// generate a new account tag
let accountTag = randomBytes(size: TAG_SIZE)

// generate the current date and time
let timestamp = currentTimestamp()

// certificate attributes
let publicKey = randomBytes(size: KEY_SIZE)
var documentTag = randomBytes(size: TAG_SIZE)
var documentVersion = "v1"

// generate a self signed certificate
var citation = "none"  // no citation for self signed documents
let certificate = generateCertificate(
    accountTag: accountTag,
    publicKey: publicKey,
    documentTag: documentTag,
    documentVersion: documentVersion
)
var document = generateDocument(
    timestamp: timestamp,
    accountTag: accountTag,
    content: certificate,
    citation: citation
)
var signature = formatLines(string: randomBytes(size: SIG_SIZE))  // pretend to sign the document
document = generateSignedDocument(
    timestamp: timestamp,
    accountTag: accountTag,
    content: certificate,
    citation: citation,
    signature: signature
)
print("certificate: \(document) ")
print()

// generate certificate citation
let digest = formatLines(string: randomBytes(size: SIG_SIZE))  // pretend to create a digest of the document
citation = generateCitation(
    documentTag: documentTag,
    documentVersion: documentVersion,
    digest: digest
)
print("citation: \(citation) ")
print()

// generate the transaction attributes
let transactionTag = randomBytes(size: TAG_SIZE)
let date = currentDate()
let time = currentTime()
let merchant = "Starbucks"
let amount = "$4.95"
documentTag = randomBytes(size: TAG_SIZE)
documentVersion = "v1"

// extract the transaction Id
let transactionId = String(transactionTag.prefix(8))
print("transactionId: \(transactionId)")
print()

// generate a signed transaction
let transaction = generateTransaction(
    transactionTag: transactionTag,
    date: date,
    time: time,
    merchant: merchant,
    amount: amount,
    documentTag: documentTag,
    documentVersion: documentVersion
)
document = generateDocument(
    timestamp: timestamp,
    accountTag: accountTag,
    content: transaction,
    citation: citation
)
signature = formatLines(string: randomBytes(size: SIG_SIZE))  // pretend to sign the document
document = generateSignedDocument(
    timestamp: timestamp,
    accountTag: accountTag,
    content: transaction,
    citation: citation,
    signature: signature
)
print("transaction: \(document) ")
print()

