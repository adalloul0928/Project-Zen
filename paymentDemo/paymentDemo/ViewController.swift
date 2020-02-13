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
import BDN
import ArmorD
import Repository

// ViewController class adopts both the central and peripheral delegates and conforms to their protocol requirements
class ViewController: UIViewController, FlowControl{
    // MARK: MODEL RELATED ASPECTS
    
    // Account tag for the user of the mobile application
    let account = formatter.generateTag()
    
    // The keys maintained by the mobile application
    var publicKey : [UInt8]?
    var mobileKey : [UInt8] = [UInt8](repeating: 0, count: KEY_SIZE)  // initialize to all zeros
    var savedCredentials : [UInt8]?
    var versionKey : Int?
    
    // content and documents
    var certificate : Document?
    var transaction : Document?
    var transactionContent : Transaction?
    var certificateCitation : Citation?
    var digest: [UInt8]?
    var credentials : Document?
    
    // bluetooth controller
    var armorD : ArmorD?
    
    // attempts if getting a failure from ArmorD device
    var attempts = 5
    
    // global stack for function calls
    var taskQueue : [functionCalls]?
    
    enum functionCalls {
        case eraseKeys
        case loadKeys
        case generateKeys
        case signCertificate
        case digestCertificate
        case signCredentials
        case signTransaction
        case digestTransaction
    }

    // MARK: VIEW RELATED ASPECTS

    @IBOutlet weak var PayMerchant: UIButton!
    @IBOutlet weak var generateKeysLabel: UIButton!
    @IBOutlet weak var EraseKeys: UIButton!
    
    @IBOutlet weak var certificateView: UIView!
    @IBOutlet weak var transactionView: UIView!
    
    @IBOutlet weak var generateKeysPopup: UILabel!
    @IBOutlet weak var signBytesPopup: UILabel!
    @IBOutlet weak var AWS_PushPopup: UILabel!
    @IBOutlet weak var closeTransactionButton: UIButton!
    @IBOutlet weak var closeCertificateButton: UIButton!
    
    @IBOutlet weak var generateKeysCheckmark: UIImageView!
    @IBOutlet weak var notarizeCertificateCheckmark: UIImageView!
    @IBOutlet weak var AWSPushCertCheckmark: UIImageView!
    @IBOutlet weak var X_GenerateKeysPop: UIImageView!
    @IBOutlet weak var X_NotarizeCertPop: UIImageView!
    
    @IBOutlet weak var notarizeTransCheckmark: UIImageView!
    @IBOutlet weak var AWSPushTransCheckmark: UIImageView!
    @IBOutlet weak var X_NotarizeTransPop: UIImageView!
    
    // MARK: VIEW BUTTON ACTIONS
    
    @IBAction func generateKeysAction(_ sender: UIButton) {
        PayMerchant.isEnabled = false
        PayMerchant.alpha = 0.5
        EraseKeys.isEnabled = false
        EraseKeys.alpha = 0.5
        generateKeysLabel.isEnabled = false
        generateKeysLabel.alpha = 0.5
        certificateView.isHidden = false
        closeCertificateButton.isEnabled = false
        
        taskQueue = [
            .eraseKeys,
            .generateKeys,
            .signCertificate,
            .digestCertificate,
            .signCredentials
        ]
        executeNextTask()
    }
    
    // This function is called when the "Pay Merchant" button is pressed
    @IBAction func payMerchant(_ sender: UIButton) {
        PayMerchant.isEnabled = false
        PayMerchant.alpha = 0.5
        EraseKeys.isEnabled = false
        EraseKeys.alpha = 0.5
        generateKeysLabel.isEnabled = false
        generateKeysLabel.alpha = 0.5
        AWSPushTransCheckmark.isHidden = true
        notarizeTransCheckmark.isHidden = true
        closeTransactionButton.isEnabled = false

        viewTransaction()
    }
    
    // function for closing the pop up for the payment transaction
    @IBAction func closeAnimation(_ sender: UIButton) {
        generateKeysCheckmark.isHidden = true
        notarizeCertificateCheckmark.isHidden = true
        AWSPushCertCheckmark.isHidden = true
        notarizeTransCheckmark.isHidden = true
        AWSPushTransCheckmark.isHidden = true
        transactionView.isHidden = true
        certificateView.isHidden = true
        EraseKeys.isEnabled = true
        EraseKeys.alpha = 1.0
        PayMerchant.isEnabled = true
        PayMerchant.alpha = 1.0
        view.backgroundColor = UIColor.white
        
        print("Closing the popup")
    }
    
    // This function is called when the "Erase Keys" button is pressed
    @IBAction func eraseKeys(_ sender: UIButton) {
        PayMerchant.isEnabled = false
        PayMerchant.alpha = 0.5
        EraseKeys.isEnabled = false
        EraseKeys.alpha = 0.5
        generateKeysLabel.isEnabled = false
        generateKeysLabel.alpha = 0.5
        
        taskQueue = [
            .eraseKeys,
        ]
        executeNextTask()
    }
    
    // MARK: LOADING APP (VIEWDIDLOAD)
    // This function is called when the application is done loading the view structure
    override func viewDidLoad() {
        super.viewDidLoad()
        
        taskQueue = [
        .loadKeys
        ]

        // Rounded edges for buttons
        PayMerchant.layer.cornerRadius = PayMerchant.frame.size.height/2
        generateKeysLabel.layer.cornerRadius = PayMerchant.frame.size.height/2
        EraseKeys.layer.cornerRadius = PayMerchant.frame.size.height/2
        transactionView.layer.cornerRadius = PayMerchant.frame.size.height/2
        certificateView.layer.cornerRadius = PayMerchant.frame.size.height/2
        // Hide the pop ups at beginning
        generateKeysCheckmark.isHidden = true
        notarizeCertificateCheckmark.isHidden = true
        AWSPushCertCheckmark.isHidden = true
        notarizeTransCheckmark.isHidden = true
        AWSPushTransCheckmark.isHidden = true
        transactionView.isHidden = true
        certificateView.isHidden = true
        X_GenerateKeysPop.isHidden = true
        X_NotarizeCertPop.isHidden = true
        X_NotarizeTransPop.isHidden = true
        
        // Do any additional setup after loading the view.
        armorD = ArmorDProxy(controller : self)
    }

    // MARK: PRIMARY FXN CALLS
    func executeNextTask() {
        let nextFunction : functionCalls = taskQueue![0]
        switch(nextFunction) {
            case .eraseKeys:
                print("Erasing Keys")
                armorD!.processRequest(type: "eraseKeys")
            case .generateKeys:
                print("Generate Keys")
                if publicKey == nil{
                    mobileKey = formatter.generateBytes(size: 32)
                    armorD!.processRequest(type: "generateKeys", mobileKey)
                }
                else{nextStep(device: armorD!, result: [1])}
            case .signCertificate:
                print("Sign Certificate")
                if publicKey != nil{
                    let content = Certificate(publicKey: publicKey!)
                    certificate = Document(account: account, content: content)
                    let bytes: [UInt8] = Array(certificate!.format(level: 0).utf8)
                    armorD!.processRequest(type: "signBytes", mobileKey, bytes)
                }
                else{print("Public Key does not exist. Notarizing failed.")}
            case .digestCertificate:
                print("Digest Certificate")
                let bytes = [UInt8](certificate!.format().utf8)
                armorD!.processRequest(type: "digestBytes", bytes)
            case .signCredentials:
                print("Sign Credentials")
                let tag = certificate!.content.tag
                let version = certificate!.content.version
                certificateCitation = Citation(tag: tag, version: version, digest: digest!)
                let content = Credentials()
                credentials = Document(account: account, content: content, certificate: certificateCitation)
                let bytes = [UInt8](credentials!.format().utf8)
                armorD!.processRequest(type: "signBytes", mobileKey, bytes)
            case .signTransaction:
                print("Sign Transaction")
                let bytes = [UInt8](transaction!.format().utf8)
                armorD!.processRequest(type: "signBytes", mobileKey, bytes)
            case .digestTransaction:
                print("Digest Transaction")
                let bytes = [UInt8](transaction!.format().utf8)
                armorD!.processRequest(type: "digestBytes", bytes)
            default:
                print("Default Case - Next task")
        }
        view.layoutIfNeeded()
    }
    
    func nextStep(device: ArmorD, result: [UInt8]?) {
        print("Success")
        X_GenerateKeysPop.isHidden = true
        X_NotarizeCertPop.isHidden = true
        X_NotarizeTransPop.isHidden = true
        attempts = 5 // reset attempts to five on a success
        let currFunction : functionCalls = taskQueue!.removeFirst()
        switch(currFunction) {
            case .eraseKeys:
                print("Erase Keys Success")
                publicKey = nil
                mobileKey = [UInt8](repeating: 0, count: KEY_SIZE)
                saveKeys()
                generateKeysLabel.isEnabled = true
                generateKeysLabel.alpha = 1.0
            case .loadKeys:
                print("Loading the keys if saved")
                loadKeys()
            case .generateKeys:
                print("Result: \(result)")
                publicKey = result
                saveKeys()
                generateKeysCheckmark.isHidden = false
            case .signCertificate:
                print("Certificate Signed")
                notarizeCertificateCheckmark.isHidden = false
                certificate!.signature = result
            case .digestCertificate:
                print("Digested certificate")
                digest = result
            case .signCredentials:
                print("Credentials signed")
                credentials!.signature = result
                EraseKeys.isEnabled = true
                EraseKeys.alpha = 1.0
                PayMerchant.isEnabled = true
                PayMerchant.alpha = 1.0
                uploadCertificate()
            case .signTransaction:
                print("Transaction signed")
                notarizeTransCheckmark.isHidden = false
                transaction!.signature = result
            case .digestTransaction:
                print("Digested transaction")
                digest = result
                uploadTransaction()
            default:
                print("Default Case - next step")
        }
        view.layoutIfNeeded()
        if !(taskQueue!.isEmpty){
            executeNextTask()
        }
    }
    
    func stepFailed(device: ArmorD, error: String) {
        print("Failure")
        let currFunction : functionCalls = taskQueue![0]
        switch(currFunction) {
            case .eraseKeys:
                EraseKeys.isEnabled = true
                EraseKeys.alpha = 1.0
                print("Erase Keys Failed")
            case .generateKeys:
                X_GenerateKeysPop.isHidden = false
                print("Generate Keys Failed")
            case .signCertificate:
                X_NotarizeCertPop.isHidden = false
                print("Sign Document Failed")
            case .digestCertificate:
                print("Digest Certificate Failed")
            case .signCredentials:
                print("Sign Credentials Failed")
            case .signTransaction:
                X_NotarizeTransPop.isHidden = false
                print("Sign Transaction Failed")
            case .digestTransaction:
                print("Digest Transaction Failed")
            default:
                print("Default Case - Step failed")
        }
        
        view.layoutIfNeeded()
        if attempts > 0{
            attempts -= 1
            usleep(1000000) // sleep 1 second
            print("Attempt's left #\(attempts)")
            executeNextTask()
        }
        else {
            taskQueue = []
            attempts = 5
            X_GenerateKeysPop.isHidden = true
            X_NotarizeCertPop.isHidden = true
            X_NotarizeTransPop.isHidden = true
            closeTransactionButton.isEnabled = true
            closeCertificateButton.isEnabled = true
            print("Device failed too many times.")
            // generate certificate / keys failed
//            ProgressHUD.showError("Failure")
            if publicKey == nil{
                generateKeysCheckmark.isHidden = true
                notarizeCertificateCheckmark.isHidden = true
                AWSPushCertCheckmark.isHidden = true
                
                certificateView.isHidden = true
                
                EraseKeys.isEnabled = false
                EraseKeys.alpha = 0.5
                generateKeysLabel.isEnabled = true
                generateKeysLabel.alpha = 1.0
                PayMerchant.isEnabled = false
                PayMerchant.alpha = 0.5
            }
            // transaction failed
            else{
                notarizeTransCheckmark.isHidden = true
                AWSPushTransCheckmark.isHidden = true
                
                transactionView.isHidden = true
                
                EraseKeys.isEnabled = true
                EraseKeys.alpha = 1.0
                generateKeysLabel.isEnabled = false
                generateKeysLabel.alpha = 0.5
                PayMerchant.isEnabled = true
                PayMerchant.alpha = 1.0
            }
        }
    }

    // Creates a dummy transaction and then presents a popup for the viewer
    func viewTransaction() {
        generateTransaction()
        let alertMessage = """
        TransactionId: \(transactionContent!.transaction.prefix(9).suffix(8))
        Merchant: \(transactionContent!.merchant)
        Amount: \(transactionContent!.amount)
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
        let amounts = ["$7.99", "$4.95", "$5.17", "$1.14", "$21.01"]
        let merchant = merchants[Int.random(in: 1..<merchants.count)]
        let amount = amounts[Int.random(in: 1..<amounts.count)]
        transactionContent = Transaction(merchant: merchant, amount: amount)
        transaction = Document(account: account, content: transactionContent!, certificate: certificateCitation)
    }
    
    // This function is called when the "Pay" button has been pressed
    func signTransaction() {
        print("Sign the transaction")
        
        transactionView.isHidden = false
        view.backgroundColor = UIColor.lightGray
        
        taskQueue = [.signTransaction, .digestTransaction]
        executeNextTask()
    }
    
    // This function is called when the "Cancel" button has been pressed
    func cancelTransaction() {
        print("Cancel the transaction")
        
        transactionView.isHidden = true
        EraseKeys.isEnabled = true
        EraseKeys.alpha = 1.0
        PayMerchant.isEnabled = true
        PayMerchant.alpha = 1.0
        view.backgroundColor = UIColor.white
        
        taskQueue = []
    }
    
    func uploadTransaction() {
        repository.writeDocument(credentials: credentials!, document: transaction!)
        let name = "/bali/examples/transaction"
        let tag = transaction!.content.tag
        let version = transaction!.content.version
        let citation = Citation(tag: tag, version: version, digest: digest!)
        repository.writeCitation(credentials: credentials!, name: name, version: String(versionKey!), citation: citation)
        versionKey! += 1
        saveKeys()
        
        AWSPushTransCheckmark.isHidden = false
        closeTransactionButton.isEnabled = true
        
        print("Success uploaded transaction document")
    }
    
    func uploadCertificate() {
        repository.writeDocument(credentials: credentials!, document: certificate!)
        let name = "/bali/examples/certificate"
        let version = certificate!.content.version
        repository.writeCitation(credentials: credentials!, name: name, version: String(versionKey!), citation: certificateCitation!)
        versionKey! += 1
        saveKeys()
        
        AWSPushCertCheckmark.isHidden = false
        closeCertificateButton.isEnabled = true
        
        print("Success uploaded certificate document")
    }
    
    func saveKeys() {
        let defaults = UserDefaults.standard
        defaults.set(publicKey, forKey: "publicKey")
        defaults.set(mobileKey, forKey: "mobileKey")
        defaults.set(versionKey, forKey: "versionKey")
    }
    
    func loadKeys() {
        let defaults = UserDefaults.standard
        let possibleSavedPublicKey = defaults.array(forKey: "publicKey")
        let possibleSavedMobileKey = defaults.array(forKey: "mobileKey")
        let possibleSavedVersionKey = defaults.integer(forKey: "versionKey")
        
        if possibleSavedPublicKey != nil {
            publicKey = possibleSavedPublicKey as! [UInt8]
            mobileKey = possibleSavedMobileKey as! [UInt8]
            versionKey = possibleSavedVersionKey
            PayMerchant.isEnabled = true
            PayMerchant.alpha = 1.0
            generateKeysLabel.isEnabled = false
            generateKeysLabel.alpha = 0.5
            EraseKeys.isEnabled = true
            EraseKeys.alpha = 1.0
        }
            // if there are no saved keys
        else{
            versionKey = 0
            PayMerchant.isEnabled = false
            PayMerchant.alpha = 0.5
            generateKeysLabel.isEnabled = true
            generateKeysLabel.alpha = 1.0
            EraseKeys.isEnabled = false
            EraseKeys.alpha = 0.5
        }
        print("Public key: \(publicKey)")
        print("Mobile key: \(mobileKey)")
        print("Version key: \(versionKey)")
    }
    
    func resetState() {
        loadKeys()

        PayMerchant.isEnabled = false
        PayMerchant.alpha = 0.5
        EraseKeys.isEnabled = false
        EraseKeys.alpha = 0.5
        PayMerchant.isHidden = true
        EraseKeys.isHidden = true
        
        // Make the process transaction view hidden along with all the different features
        transactionView.isHidden = true

        // load the function stack when first loading the program (generate keys, sign and upload certificate)
        taskQueue = [
            .generateKeys,
            .eraseKeys,
        ]
        executeNextTask()
    }
}


