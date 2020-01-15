//
//  ViewController.swift
//  paymentDemo
//
//  Created by Aren Dalloul on 8/23/19.
//  Copyright © 2019 Aren Dalloul. All rights reserved.
//

// Import CoreBluetooth for BLE functionality
import UIKit
import CoreBluetooth
import Foundation
import AVKit
import AVFoundation
import AWSS3
import BDN
import ArmorD

// ViewController class adopts both the central and peripheral delegates and conforms to their protocol requirements
class ViewController: UIViewController, FlowControl{
    // MODEL RELATED ASPECTS
    
    // Account tag for the user of the mobile application
    let account = formatter.generateTag()
    
    // The keys maintained by the mobile application
    var publicKey : [UInt8]?
//    var mobileKey : [UInt8]?  // initialize to all zeros
    var mobileKey : [UInt8] = [UInt8](repeating: 0, count: KEY_SIZE)  // initialize to all zeros
    
    // content and documents
    var certificate : Document?
    var transaction : Document?
    var transactionContent : Transaction?
    var documentSignature : [UInt8]?
//    var document : Document?
    var certificateCitation : Citation?
    
    // bluetooth controller
    var armorD : ArmorD?
    
    // global stack for function calls
    var taskQueue : [functionCalls]?

    // VIEW RELATED ASPECTS

    @IBOutlet weak var PayMerchant: UIButton!
    
    @IBOutlet weak var GenerateKeys: UILabel!
    
    @IBOutlet weak var SignBytes: UILabel!
    
    @IBOutlet weak var AWS_Push: UILabel!
    
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var generateKeysCheckmark: UIImageView!
    
    @IBOutlet weak var signBytesCheckmark: UIImageView!
    
    @IBOutlet weak var AWSPushCheckmark: UIImageView!
    
    @IBOutlet weak var processView: UIView!
    
    @IBOutlet weak var EraseKeys: UIButton!
    
    // function for closing the pop up for the payment transaction
    @IBAction func closeAnimation(_ sender: UIButton) {
        processView.isHidden = true
        view.backgroundColor = UIColor.white
        print("Closing the application")
    }
    
    // This function is called when the "Erase Keys" button is pressed
    @IBAction func eraseButton(_ sender: UIButton) {
        PayMerchant.isEnabled = false
        EraseKeys.isEnabled = false
        taskQueue = [
            .eraseKeys,
        ]
        executeNextTask()
    }
    
    // This function is called when the "Pay Merchant" button is pressed
    @IBAction func payMerchant(_ sender: UIButton) {
        PayMerchant.isEnabled = false
        EraseKeys.isEnabled = false
        closeButton.isEnabled = false
        
        AWSPushCheckmark.isHidden = true
        signBytesCheckmark.isHidden = true
        generateKeysCheckmark.isHidden = true
        
        taskQueue = [
            .viewTransaction
        ]
        executeNextTask()
    }
    
    // This function is called when the application is done loading the view structure
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let accessKey = "..."
        let secretKey = "..."
        
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest2, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Initialize the state of the application
//        resetState()

        // Rounded edges for buttons
        PayMerchant.layer.cornerRadius = PayMerchant.frame.size.height/2
        processView.layer.cornerRadius = PayMerchant.frame.size.height/2
        processView.isHidden = true
        
        // Do any additional setup after loading the view.
        armorD = ArmorDProxy(controller : self)
        
        // Generate initial document
        generateInitialDocument()
    }

    func stepFailed(device: ArmorD, error: String) {
        print("Failure")
        let currFunction : functionCalls = taskQueue!.removeFirst()
        switch(currFunction) {
            case .generateKeys:
                print("Generate Keys Failed")
            case .viewTransaction:
                print("View Transaction Failed")
            case .signDocument:
                print("Sign Document Failed")
            case .uploadCertificate:
                print("Upload Certificate Failed")
            case .uploadTransaction:
                print("Upload Transaction Failed")
            case .eraseKeys:
                print("Erase Keys Failed")
            default:
                print("Default Case - Please input correct function")
        }
        view.layoutIfNeeded()
        // need to add what happens if failed. Reset everything.
    }
    
    func nextStep(device: ArmorD, result: [UInt8]?) {
        print("Success")
        // Do we need to add an if statement checking for an empty queue? This will break if queue is empty
        let currFunction : functionCalls = taskQueue!.removeFirst()
        switch(currFunction) {
            case .generateKeys:
                publicKey = result
                generateCertificate()
                generateKeysCheckmark.isHidden = false
            case .viewTransaction:
                print("View Transaction Success")
            case .signDocument:
                documentSignature = result
                signBytesCheckmark.isHidden = false
            case .uploadCertificate:
                AWSPushCheckmark.isHidden = false
            case .uploadTransaction:
                AWSPushCheckmark.isHidden = false
            case .eraseKeys:
                print("Erase Keys Success")
            default:
                print("Default Case - Please input correct function")
        }
        view.layoutIfNeeded()
        executeNextTask()
    }
    
    // CONTROLLER RELATED ASPECTS

    enum functionCalls {
        case generateKeys
        case viewTransaction
        case appendTransactionSignature
        case appendCertificateSignature
        case signCertificate
        case signDocument
        case uploadCertificate
        case uploadTransaction
        case citeDocument
        case uploadCitation
        case eraseKeys
    }
    
    func executeNextTask() {
        let nextFunction : functionCalls = taskQueue![0]
        switch(nextFunction) {
            case .generateKeys:
                generateKeys()
            case .signCertificate:
                signDocument(document : certificate)
            case .viewTransaction:
                viewTransaction()
            case .appendCertificateSignature:
                appendCertificateSignature()
            case .appendTransactionSignature:
                appendTransactionSignature()
            case .uploadTransaction:
                uploadTransaction()
            case .uploadCertificate:
                uploadCertificate()
            case .eraseKeys:
                eraseKeys()
            default:
                print("Default Case - Please input correct function")
        }
        view.layoutIfNeeded()
    }
    
    func generateInitialDocument() {
        taskQueue = [
            .generateKeys,
            .signCertificate,
            .appendCertificateSignature,
            .uploadCertificate
        ]
        executeNextTask()
    }
    
    /**
    * This function generates a new document
    */
    func generateCertificate(){
        let account = formatter.generateTag()
        let publicKeyBytes: String = String(bytes: publicKey!, encoding: .utf8)!
        let content = Certificate(publicKey: publicKeyBytes)
        certificate = Document(account: account, content: content)
    }

    // Creates a dummy transaction and then presents a popup for the viewer
    func viewTransaction() {
        // we only need the first 8 characters of the transaction tag
        generateTransaction()
        let alertMessage = """
        TransactionId: \(transactionContent?.transaction.prefix(9).suffix(8))
        Date: \(transactionContent?.date)
        Time: \(transactionContent?.time)
        Merchant: \(transactionContent?.merchant)
        Amount: \(transactionContent?.amount)
        """
        let alert = UIAlertController(title: "Pay Merchant", message: alertMessage, preferredStyle: .alert)
        let approvePayment = UIAlertAction(title: "Pay", style: .default, handler: { (UIAlertAction) in self.signTransaction()})
        let cancelPayment = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: { (UIAlertAction) in self.cancelTransaction()})
        
        alert.addAction(approvePayment)
        alert.addAction(cancelPayment)
        
        present(alert, animated: true, completion: nil)
    }
    
    func generateTransaction() {
        let merchants = [
            "Starbucks",
            "BestBuy",
            "Target",
            "Lyft",
            "Chipotle"
        ]
        let amounts = ["$7.99", "$4.95", "$5.17", "$1.14", "$21.00"]
        let merchant = merchants[Int.random(in: 1..<merchants.count)]
        let amount = amounts[Int.random(in: 1..<amounts.count)]
        transactionContent = Transaction(merchant: merchant, amount: amount)
        transaction = Document(account: account, content: transactionContent!)
    }
    
    // This function is called when the "Pay" button has been pressed
    func signTransaction() {
        print("Sign the transaction")
        processView.isHidden = false
        view.backgroundColor = UIColor.lightGray
        taskQueue = [.appendTransactionSignature, .uploadTransaction]
        signDocument(document : transaction)
    }
    
    // This function is called when the "Cancel" button has been pressed
    func cancelTransaction() {
        print("Cancel the transaction")
//        processView.isHidden = true
//        view.backgroundColor = UIColor.lightGray
        executeNextTask()
    }
    
    func resetState() {
        loadKeys()

        PayMerchant.isEnabled = false
        EraseKeys.isEnabled = false
        
        PayMerchant.isHidden = true
        EraseKeys.isHidden = true
        
        // Make the process transaction view hidden along with all the different features
        processView.isHidden = true

        // load the function stack when first loading the program (generate keys, sign and upload certificate)
        taskQueue = [
            .generateKeys,
            .eraseKeys,
        ]
        executeNextTask()
    }

    /**
     * This function generates a new public-private key pair.
     */
    func generateKeys() {
        if publicKey == nil {
            do {
                print("Generating a new key pair.")
                let status = SecRandomCopyBytes(kSecRandomDefault, KEY_SIZE, &mobileKey)
                if status == errSecSuccess { // Always test the status.
                    print(mobileKey)
                    // Prints something different every time you run.
                }
                print("ArmorD")
                print(armorD)
                armorD!.processRequest(type: "generateKeys", mobileKey)
            } catch {
                print("A new key pair could not be generated")
            }
        } else {
            // the key pair already exists so continue with the next step
            generateKeysCheckmark.isHidden = false
            executeNextTask()
        }
    }
    
    /**
     * This function deletes any existing public-private key pairs.
     *
     * @returns Whether or not the keys were successfully erased.
     */
    func eraseKeys() {
        print("Erasing Keys")
        publicKey = nil
        mobileKey = [UInt8](repeating: 0, count: KEY_SIZE)
        saveKeys()
        armorD!.processRequest(type: "eraseKeys")
    }
    
    /**
     * This function generates a digital signature of the specified bytes using
     * the private key. The resulting digital signature can then be verified
     * using the corresponding public key.
     *
     * @param bytes A byte array containing the bytes to be digitally signed.
     * @returns A byte array containing the resulting digital signature.
     */
    func signDocument(document: Document?) {
        print("Signing the document")
        SignBytes.isHidden = false
        AWS_Push.isHidden = false
        let bytes: [UInt8] = Array(document!.format(level: 0).utf8)
        armorD!.processRequest(type: "signBytes", mobileKey, bytes)
    }
    
    func appendTransactionSignature(){
        let content = transaction!.content
        let signatureString : String = String(bytes : documentSignature!, encoding : .utf8)!
        transaction = Document(account: account, content: content, certificate: certificateCitation, signature: signatureString)
    }
    
    func appendCertificateSignature(){
        let content = certificate!.content
        let signatureString : String = String(bytes : documentSignature!, encoding : .utf8)!
        certificate = Document(account: account, content: content, signature: signatureString)
    }
    
    func uploadTransaction() {
            print("Success uploaded transaction document")
        nextStep(device: armorD!, result: [1])
        }
    
    func uploadCertificate() {
        print("Success uploaded certificate document")
        nextStep(device: armorD!, result: [1])
//        let fileManager = FileManager.default
//
//        // Write the document to a file
//        let path = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let filename = path.appendingPathComponent("document.bali")
//        do {
//            try document!.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
//            print("The document was written to the file successfully.")
//        } catch let error as NSError {
//            print("Couldn't write to file: \(error.localizedDescription)")
//        }
//
//        // upload the file to AWS S3 bucket
//        let uploadRequest = AWSS3TransferManagerUploadRequest()!
//        uploadRequest.body = filename
//        uploadRequest.key = "documents/\(document!.content.tag.suffix(32))/\(document!.content.version).bali"
//        uploadRequest.bucket = "craterdog-bali-documents-us-west-2"
//        uploadRequest.contentType = "application/bali"
//        // uploadRequest.acl = .publicReadWrite  **DONT SET AN ACL (ACLs are obsolete)**
//        let transferManager = AWSS3TransferManager.default()
//        transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task) -> Any? in
//            if let error = task.error {
//                print("Unable to upload the file: \(error)")
//            }
//            if task.result != nil {
//                print("The file was uploaded successfully.")
//            }
//            return nil
//        }
    }
    
    func saveKeys() {
        let defaults = UserDefaults.standard
        defaults.set(publicKey, forKey: "publicKey")
        defaults.set(mobileKey, forKey: "mobileKey")
    }
    
    func loadKeys() {
        let defaults = UserDefaults.standard
        let possibleSavedPublicKey = defaults.array(forKey: "publicKey")
        let possibleSavedMobileKey = defaults.array(forKey: "mobileKey")
        
        if possibleSavedPublicKey != nil {
            publicKey = possibleSavedPublicKey as! [UInt8]
            mobileKey = possibleSavedMobileKey as! [UInt8]
        }
        print("Public key: \(publicKey)")
        print("Mobile key: \(mobileKey)")
    }
}
