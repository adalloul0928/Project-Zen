import Foundation

//TEST Formatter, Document, Certificate, and Citation

// generate a new account tag and public key
let account = formatter.generateTag()
let publicKey = formatter.generateKey()

// create a new certificate
let certificate = Certificate(publicKey: publicKey)
var document = Document(account: account, content: certificate)

// pretend to sign the certificate document
var signature = formatter.generateSignature()
document = Document(account: account, content: certificate, signature: signature)

print("certificate: \(document.format(level: 0))")
print()

// pretend to create a digest of the signed certificate document
let digest = formatter.generateDigest()

// generate a certificate citation
let tag = certificate.tag
let version = certificate.version
let citation = Citation(tag: tag, version: version, digest: digest)

print("citation: \(citation.format(level: 0))")
print()

// create a new transaction
let merchant = "Starbucks"
let amount = "$4.95"
let transaction = Transaction(merchant: merchant, amount: amount)
document = Document(account: account, content: transaction, certificate: citation)

// pretend to sign the certificate document
signature = formatter.generateSignature()
document = Document(account: account, content: transaction, certificate: citation, signature: signature)

print("transaction: \(document.format(level: 0))")
print()

// extract the transaction Id
let transactionId = String(transaction.transaction.prefix(9).suffix(8))
print("transactionId: \(transactionId)")
print()


// TEST ArmorDProxy
class FlowController: FlowControl {
    var step = 0
    var bytes = formatter.generateBytes(size: 500)
    var signature: [UInt8]?
    var digest: [UInt8]?
    var mobileKey = formatter.generateBytes(size: 64)
    var publicKey: [UInt8]?

    func stepFailed(reason: String) {
        print("Step failed: \(reason)")
    }
    
    func stepSucceeded(device: ArmorD, result: [UInt8]?) {
        step += 1
        switch (step) {
            case 1:
                device.processRequest(type: "eraseKeys")
            case 2:
                print("Keys erased: \(String(describing: result))")
                device.processRequest(type: "generateKeys", mobileKey)
            case 3:
                print("Keys generated: \(String(describing: result))")
                publicKey = result
                device.processRequest(type: "signBytes", mobileKey, bytes)
            case 4:
                print("Bytes signed: \(String(describing: result))")
                signature = result
                device.processRequest(type: "validSignature", publicKey!, signature!, bytes)
            case 5:
                print("Signature valid: \(String(describing: result))")
                device.processRequest(type: "digestBytes", bytes)
            case 6:
                print("Bytes digested: \(String(describing: result))")
                digest = result
                device.processRequest(type: "eraseKeys")
            default:
                return  // done
        }
    }
}

let controller = FlowController()
let armorD = ArmorDProxy(controller: controller)

//armorD.processRequest(type: String, _ args: [UInt8]...)
//case "generateKeys":
//case "rotateKeys":
//case "eraseKeys":
//case "digestBytes":
//case "signBytes":
//case "validSignature":

controller.stepSucceeded(device: armorD, result: nil)

print("Sleeping...")
Thread.sleep(forTimeInterval: 30)
print("Yawn.")

