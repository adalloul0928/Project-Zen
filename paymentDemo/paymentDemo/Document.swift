import Foundation

// the number of bytes in a tag
let TAG_SIZE = 20

// the number of bytes in a key
let KEY_SIZE = 32

// the number of bytes in a signature
let SIG_SIZE = 64

// the line width for formatting encoded byte strings
let LINE_WIDTH = 60

// the POSIX end of line character
let EOL = "\n"


// define the template for a certificate
let certificateTemplate = """
[
$protocol: v1
$timestamp: <{timestamp}>
$accountTag: #{accountTag}
$publicKey: '{publicKey}'
](
$type: /bali/notary/Certificate/v1
$tag: #{documentTag}
$version: v1
$permissions: /bali/permissions/public/v1
$previous: none
)
"""

// define the template for a document
let documentTemplate = """
[
$component: {component}
$protocol: v1
$timestamp: <{timestamp}>
$certificate: none
$signature: '{signature}
'
](
$type: /bali/notary/Document/v1
)
"""

func currentTimestamp() -> String {
    let now = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let timestamp = formatter.string(from: now)
    return timestamp
}

/*
 * Define a lookup table for mapping five bit values to base 32 characters.
 * It eliminate 4 vowels ("E", "I", "O", "U") to reduce any confusion with 0 and O, 1
 * and I; and reduce the likelihood of *actual* (potentially offensive) words from being
 * included in a base 32 string. Only uppercase letters are allowed.
 */
let base32LookupTable = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "A", "B", "C", "D", "F", "G", "H", "J", "K", "L",
    "M", "N", "P", "Q", "R", "S", "T", "V", "W", "X",
    "Y", "Z"
]
func lookupCharacter(index: UInt8) -> String {
    return base32LookupTable[Int(index)]
}

/*
 * offset:    0        1        2        3        4        0
 * byte:  00000111|11222223|33334444|45555566|66677777|...
 * mask:   F8  07  C0 3E  01 F0  0F 80  7C 03  E0  1F   F8  07
 */
func base32EncodeBytes(previous: UInt8, current: UInt8, byteIndex: Int, base32: String) -> String {
    var result = base32
    var chunk: UInt8
    let offset = byteIndex % 5
    switch offset {
    case 0:
        chunk = (current & 0xF8) >> 3
        result += lookupCharacter(index: chunk)
    case 1:
        chunk = ((previous & 0x07) << 2) | ((current & 0xC0) >> 6)
        result += lookupCharacter(index: chunk)
        chunk = (current & 0x3E) >> 1
        result += lookupCharacter(index: chunk)
    case 2:
        chunk = ((previous & 0x01) << 4) | ((current & 0xF0) >> 4)
        result += lookupCharacter(index: chunk)
    case 3:
        chunk = ((previous & 0x0F) << 1) | ((current & 0x80) >> 7)
        result += lookupCharacter(index: chunk)
        chunk = (current & 0x7C) >> 2
        result += lookupCharacter(index: chunk)
    case 4:
        chunk = ((previous & 0x03) << 3) | ((current & 0xE0) >> 5)
        result += lookupCharacter(index: chunk)
        chunk = current & 0x1F
        result += lookupCharacter(index: chunk)
    default:
        break
    }
    return result
}


/*
 * Same as normal, but pad with 0's in "next" byte
 * case:      0        1        2        3        4
 * byte:  xxxxx111|00xxxxx3|00004444|0xxxxx66|000xxxxx|...
 * mask:   F8  07  C0 3E  01 F0  0F 80  7C 03  E0  1F
 */
func base32EncodeLast(last: UInt8, byteIndex: Int, base32: String) -> String {
    var result = base32
    var chunk: UInt8
    let offset = byteIndex % 5
    switch offset {
    case 0:
        chunk = (last & 0x07) << 2
        result += lookupCharacter(index: chunk)
    case 1:
        chunk = (last & 0x01) << 4
        result += lookupCharacter(index: chunk)
    case 2:
        chunk = (last & 0x0F) << 1
        result += lookupCharacter(index: chunk)
    case 3:
        chunk = (last & 0x03) << 3
        result += lookupCharacter(index: chunk)
        //  case 4:
    //      nothing to do, was handled by previous call
    default:
        break
    }
    return result
}


/**
 * This function encodes the bytes in an array into a base 32 string.
 *
 * @param {[UInt8]} bytes An array containing the bytes to be encoded.
 * @return {String} The base 32 encoded string.
 */
func base32Encode(bytes: [UInt8]) -> String {
    // encode each byte
    var string = ""
    let count = bytes.count
    for i in 0..<count {
        let previousByte = (i == 0) ? 0x00 : bytes[i - 1]  // ignored when i is zero
        let currentByte = bytes[i]
        
        // encode next one or two 5 bit chunks
        string = base32EncodeBytes(previous: previousByte, current: currentByte, byteIndex: i, base32: string)
    }
    
    // encode the last 5 bit chunk
    let lastByte = bytes[count - 1]
    string = base32EncodeLast(last: lastByte, byteIndex: count - 1, base32: string)
    
    // break the string into formatted lines
    return string
}


func randomBytes(size: Int) -> String {
    let bytes = [UInt8](repeating: 0, count: size).map { _ in UInt8.random(in: 0..<255) }
    return base32Encode(bytes: bytes)
}

func formatLines(string: String) -> String {
    var result = ""
    var index = 0
    for character in string {
        if (index % LINE_WIDTH) == 0 {
            result += EOL
        }
        result.append(character)
        index += 1;
    }
    return result
}

func indentLines(string: String, level: Int) -> String {
    var indented = string
    var count = level
    while count > 0 {
        indented = indented.replacingOccurrences(of: EOL, with: EOL + "    ")
        count -= 1
    }
    return indented
}

func generateCertificate(accountTag: String, publicKey: String) -> String {
    // format the current timestamp
    let timestamp = currentTimestamp()
    
    // generate a new document tag
    let documentTag = randomBytes(size: TAG_SIZE)
    
    // fill in certificate document
    var certificate = certificateTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
    certificate = certificate.replacingOccurrences(of: "{accountTag}", with: accountTag)
    certificate = certificate.replacingOccurrences(of: "{documentTag}", with: documentTag)
    certificate = certificate.replacingOccurrences(of: "{publicKey}", with: publicKey)
    return certificate
}

func generateDocument(certificate: String, signature: String) -> String {
    // format the current timestamp
    let timestamp = currentTimestamp()
    
    // fill in certificate document
    var document = documentTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
    document = document.replacingOccurrences(of: "{component}", with: indentLines(string: certificate, level: 1))
    document = document.replacingOccurrences(of: "{signature}", with: indentLines(string: signature, level: 2))
    return document
}

func generateTransactionCertificate(date: String, accountTag: String, publicKey: String, merchant: String, amount: String) -> String {
    // format the current timestamp
    let timestamp = currentTimestamp()
    
    // generate a new document tag
    let documentTag = randomBytes(size: TAG_SIZE)
    
    // fill in certificate document
    var certificate = transactionCertificateTemplate.replacingOccurrences(of: "{timestamp}", with: timestamp)
    certificate = certificate.replacingOccurrences(of: "{dateFormatted}", with: date)
    certificate = certificate.replacingOccurrences(of: "{accountTag}", with: accountTag)
    certificate = certificate.replacingOccurrences(of: "{merchant}", with: merchant)
    certificate = certificate.replacingOccurrences(of: "{amount}", with: amount)
    certificate = certificate.replacingOccurrences(of: "{documentTag}", with: documentTag)
    certificate = certificate.replacingOccurrences(of: "{publicKey}", with: publicKey)
    return certificate
}


let transactionCertificateTemplate = """
[
$protocol: v1
$date: {dateFormatted}
$timestamp: <{timestamp}>
$accountTag: #{accountTag}
$publicKey: '{publicKey}'
$merchant: {merchant}
$amount: {amount}
](
$type: /bali/notary/Certificate/v1
$tag: #{documentTag}
$version: v1
$permissions: /bali/permissions/public/v1
$previous: none
)
"""

//AccountId: \(accountIDSubstring)
//Merchant: \(merchant)
//Date: \(dateFormatted)
//Time: 11:30:00 AM
//Amount: $\(amount)
//"""

// TEST IT OUT

//let accountTagString = randomBytes(size: TAG_SIZE)
//let publicKeyString = randomBytes(size: KEY_SIZE)
//let publicKeyString = base32Encode(bytes : publicKey)
//let certificate = generateCertificate(accountTag: accountTagString, publicKey: publicKeyString)

// SIGNATURE EQUIVALENT TO SIGNED BYTES
//let signature = formatLines(string: base32Encode(bytes : signedBytes))
//let document = generateDocument(certificate: certificate, signature: signature)
