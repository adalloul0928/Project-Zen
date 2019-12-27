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


// ViewController class adopts both the central and peripheral delegates and conforms to their protocol requirements
class ViewController: UIViewController {

    // MODEL RELATED ASPECTS
    
    // Account tag for the user of the mobile application
    let account = formatter.generateTag()
    
    // The keys maintained by the mobile application
    var publicKey : [UInt8]?
    var mobileKey = [UInt8](repeating: 0, count: KEY_SIZE)  // initialize to all zeros
    
    // content and documents
    var certificate : Certificate?
    var transaction : Transaction?
    var document : Document?
    var citation : Citation?
    
    // bluetooth controller
    var bluetooth : BluetoothController?
    

    // VIEW RELATED ASPECTS

    @IBOutlet weak var PayMerchant: UIButton!

    @IBOutlet weak var ConnectDevice: UILabel!
    
    @IBOutlet weak var GenerateKeys: UILabel!
    
    @IBOutlet weak var SignBytes: UILabel!
    
    @IBOutlet weak var AWS_Push: UILabel!
    
    @IBOutlet weak var DisconnectDevice: UILabel!
    
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var connectCheckmark: UIImageView!
    
    @IBOutlet weak var generateKeysCheckmark: UIImageView!
    
    @IBOutlet weak var signDocumentCheckmark: UIImageView!
    
    @IBOutlet weak var AWSPushCheckmark: UIImageView!
    
    @IBOutlet weak var disconnectCheckmark: UIImageView!
    
    @IBOutlet weak var processView: UIView!
    
    @IBOutlet weak var EraseKeys: UIButton!
    
    @IBAction func closeAnimation(_ sender: UIButton) {
        processView.isHidden = true
        view.backgroundColor = UIColor.white
        print("Closing the application")
    }
    
    // This function is called when the "Erase Keys" button is pressed
    @IBAction func eraseButton(_ sender: UIButton) {
        PayMerchant.isEnabled = false
        EraseKeys.isEnabled = false
        taskStack = [
            .disconnectDevice,
            .eraseKeys,
            .connectDevice
        ]
        executeNextTask()
    }
    
    // This function is called when the "Pay Merchant" button is pressed
    @IBAction func buttonPressed(_ sender: UIButton) {
        PayMerchant.isEnabled = false
        EraseKeys.isEnabled = false
        closeButton.isEnabled = false
        
        connectCheckmark.isHidden = true
        signDocumentCheckmark.isHidden = true
        AWSPushCheckmark.isHidden = true
        disconnectCheckmark.isHidden = true
        
        taskStack = [
            .disconnectDevice,
            .uploadDocument,
            .signDocument,
            .connectDevice,
            .viewTransaction
        ]
        executeNextTask()
    }
    
    func viewTransaction() {
        // we only need the first 8 characters of the transaction tag
        let alertMessage = """
        TransactionId: \(transaction.transaction.prefix(9).suffix(8))
        Date: \(transaction.date)
        Time: \(transaction.time)
        Merchant: \(transaction.merchant)
        Amount: \(transaction.amount)
        """
        let alert = UIAlertController(title: "Pay Merchant", message: alertMessage, preferredStyle: .alert)
        let approvePayment = UIAlertAction(title: "Pay", style: .default, handler: { (UIAlertAction) in signTransaction()})
        let cancelPayment = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: { (UIAlertAction) in cancelTransaction()})
        
        alert.addAction(approvePayment)
        alert.addAction(cancelPayment)
        
        present(alert, animated: true, completion: nil)
    }
    
    // This function is called when the application is done loading the view structure
    override func viewDidLoad() {
        super.viewDidLoad()
//        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USWest2, identityPoolId:"us-west-2:da2059d0-c5ab-48d1-bfb7-d90772984bfe")
//        let configuration = AWSServiceConfiguration(region:.USWest2, credentialsProvider:credentialsProvider)
//        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
//        let accessKey = ""
//        let secretKey = ""
        
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let configuration = AWSServiceConfiguration(region: AWSRegionType.USWest2, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Initialize the state of the application
        resetState()

        // Rounded edges for buttons
        PayMerchant.layer.cornerRadius = PayMerchant.frame.size.height/2
        processView.layer.cornerRadius = PayMerchant.frame.size.height/2
        
        // Do any additional setup after loading the view.
        bluetooth = BluetoothController()
    }


    // CONTROLLER RELATED ASPECTS

    enum functionCalls {
        case connectDevice
        case generateKeys
        case viewTransaction
        case payMerchant
        case signDocument
        case uploadDocument
        case citeDocument
        case uploadCitation
        case eraseKeys
        case disconnectDevice
    }

    // global stack for function calls
    var taskStack : [functionCalls]?
    
    func executeNextTask() {
        let nextFunction = taskStack!.popLast()
        switch(nextFunction) {
            case .connectDevice:
                connectToDevice()
            case .generateKeys:
                generateKeys()
            case .viewTransaction:
                viewTransaction()
            case .signDocument:
                signDocument()
            case .uploadDocument:
                uploadDocument()
            case .eraseKeys:
                eraseKeys()
            default:
                disconnectFromDevice()
        }
        view.layoutIfNeeded()
    }

    func checkResponse(response : [UInt8]) {
        if response[0] == 255 {
            print("Request type \(requestType) failed with a 255 response")
            // reset the application state
            resetState()
        } else {
            switch(requestType) {
            case 0:
                print("Handling a process block response")
                // process the next block
                processRequest(request)
                return // bypass the stack manager
            case 1:
                print("Handling a generate keys response")
                generateKeysCheckmark.isHidden = false
                publicKey = response
                saveKeys()
                print("  public key: \(publicKey)")
                print("  mobile key: \(mobileKey)")
            case 2:
                // Add in saving default values
                print("Handling a rotate keys response")
                publicKey = response
                print("  new public key: \(publicKey)")
            case 3:
                print("Handling an erase keys response")
                if response[0] == 1 {
                    print("The keys were erased")
                } else if response[1] == 0 {
                    print("The keys could NOT be erased")
                }
            case 4:
                print("CASE Digest Bytes - NEED TO IMPLEMENT")
            case 5:
                print("Sign Bytes Response")
                signDocumentCheckmark.isHidden = false
                AWSPushCheckmark.isHidden = false
                let signature = "'\(formatter.formatLines(formatter.base32Encode(response)))'"
                print("Signature: \(signature)")
                document = Document(account: account, content: content, certificate: citation, signature: signature)
                uploadDocument()
            case 6:
                print("Signature Valid Response")
                if response[0] == 1 {
                    print("Is Valid Signature")
                } else if response[1] == 0 {
                    print("Signature NOT Valid")
                }
                
            default:
                print("Error: received a response to an unknown request type")
                print("  request type: \(requestType)")
                print("  response: \(response)")
                resetState()
            }
        }
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
        taskStack = [
            .disconnectDevice,
            .uploadDocument,
            .signDocument,
            .generateKeys,
            .eraseKeys,
            .connectDevice
        ]
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
                request = formatRequest("generateKeys", mobileKey)
                processRequest(request)
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
        mobileKey = nil
        saveKeys()
        request = formatRequest("eraseKeys")
        processRequest(request)
    }
    
    /**
     * This function generates a digital signature of the specified bytes using
     * the private key. The resulting digital signature can then be verified
     * using the corresponding public key.
     *
     * @param bytes A byte array containing the bytes to be digitally signed.
     * @returns A byte array containing the resulting digital signature.
     */
    func signDocument() {
        print("Signing the document")
        SignBytes.isHidden = false
        AWS_Push.isHidden = false
        let bytes: [UInt8] = Array(document!.utf8)
        request = formatRequest("signBytes", mobileKey, bytes)
        processRequest(request)
    }
    
    /**
     * This function uses the specified public key to determine whether or not
     * the specified digital signature was generated using the corresponding
     * private key on the specified bytes.
     *
     * @param aPublicKey A byte array containing the public key to be
     * used to validate the signature.
     * @param signature A byte array containing the digital signature
     * allegedly generated using the corresponding private key.
     * @param bytes A byte array containing the digitally signed bytes.
     * @returns Whether or not the digital signature is valid.
     */
    func validSignature(aPublicKey : [UInt8], signature : [UInt8], bytes : [UInt8]) {
        request = formatRequest("validSignature", aPublicKey, signature, bytes)
        processRequest(request)
    }
    
    func uploadDocument() {
        let fileManager = FileManager.default

        // Write the document to a file
        let path = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = path.appendingPathComponent("document.bali")
        do {
            try document!.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
            print("The document was written to the file successfully.")
        } catch let error as NSError {
            print("Couldn't write to file: \(error.localizedDescription)")
        }

        // upload the file to AWS S3 bucket
        let uploadRequest = AWSS3TransferManagerUploadRequest()!
        uploadRequest.body = filename
        uploadRequest.key = "documents/\(document.content.tag.suffix(32))/\(document.content.version).bali"
        uploadRequest.bucket = "craterdog-bali-documents-us-west-2"
        uploadRequest.contentType = "application/bali"
        // uploadRequest.acl = .publicReadWrite  **DONT SET AN ACL (ACLs are obsolete)**
        let transferManager = AWSS3TransferManager.default()
        transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task) -> Any? in
            if let error = task.error {
                print("Unable to upload the file: \(error)")
            }
            if task.result != nil {
                print("The file was uploaded successfully.")
            }
            return nil
        }
    }
    
    // This function is called when the "Pay" button has been pressed
    func signTransaction() {
        print("Sign the transaction")
        processView.isHidden = false
        view.backgroundColor = UIColor.lightGray
        taskStack = [.disconnectDevice, .uploadDocument, .signDocument, .connectDevice]
        executeNextTask()
    }
    
    // This function is called when the "Cancel" button has been pressed
    func cancelTransaction() {
        print("Cancel the transaction")
        processView.isHidden = false
        view.backgroundColor = UIColor.lightGray
        executeNextTask()
    }
    
    func payMerchant() {
        var merchants = [
            "Starbucks",
            "BestBuy",
            "Target",
            "Lyft",
            "Chipotle"
        ]
        var amounts = ["$7.99", "$4.95", "$5.17", "$1.14", "$21.00"]
        var merchant = merchants[Int.random(in: 1..<merchants.count)]
        var amount = amounts[Int.random(in: 1..<amounts.count)]
        transaction = Transaction(merchant: merchant, amount: amount)
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
