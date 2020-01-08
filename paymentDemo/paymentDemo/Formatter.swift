import Foundation

// the number of bytes in a tag
let TAG_SIZE = 20

// the number of bytes in a key
let KEY_SIZE = 32

// the number of bytes in a digest
let DIG_SIZE = 64

// the number of bytes in a signature
let SIG_SIZE = 64

// the line width for formatting encoded byte strings
let LINE_WIDTH = 60

// the POSIX end of line character
let EOL = "\n"

/*
 * Return a byte array containing the specified number of random bytes.
 */
func randomBytes(size: Int) -> [UInt8] {
    let bytes = [UInt8](repeating: 0, count: size).map { _ in UInt8.random(in: 0..<255) }
    return bytes
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


class Formatter {

    func currentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        let now = Date()
        return formatter.string(from: now)
    }

    func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let now = Date()
        return formatter.string(from: now)
    }

    func currentTimestamp() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "<yyyy-MM-dd'T'HH:mm:ss.SSS>"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: now)
    }

    func generateBytes(size: Int) -> [UInt8] {
        return randomBytes(size: size)
    }

    func generateTag() -> String {
        let bytes = randomBytes(size: TAG_SIZE)
        return "#\(base32Encode(bytes: bytes))"
    }

    func generateKey() -> String {
        let bytes = randomBytes(size: KEY_SIZE)
        return "'\(base32Encode(bytes: bytes))'"
    }

    func generateDigest() -> String {
        let bytes = randomBytes(size: DIG_SIZE)
        return formatLines(string: base32Encode(bytes: bytes))
    }

    func generateSignature() -> String {
        let bytes = randomBytes(size: SIG_SIZE)
        return formatLines(string: base32Encode(bytes: bytes))
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

}
let formatter = Formatter()

// TEST CODE

/*
let tag = formatter.generateTag()
print("tag: \(tag)")
print()

let key = formatter.generateKey()
print("key: \(key)")
print()

let digest = formatter.generateDigest()
print("digest: '\(formatter.indentLines(string: digest, level: 1))\(EOL)'")
print()

let signature = formatter.generateSignature()
print("signature: \(signature)")
print()
*/
