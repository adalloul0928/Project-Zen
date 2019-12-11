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


// ViewController class adopts both the central and peripheral delegates and conforms to their protocol's requirements
class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

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
        globalStack = [
            .disconnectDevice,
            .eraseKeys,
            .connectDevice
        ]
        executeNextFunction()
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
        
        globalStack = [
            .disconnectDevice,
            .uploadDocument,
            .signDocument,
            .connectDevice,
            .viewTransaction
        ]
        executeNextFunction()
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
       centralManager = CBCentralManager(delegate: self, queue: nil)
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
    var globalStack : [functionCalls]?
    
    func executeNextFunction() {
        let nextFunction = globalStack!.popLast()
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
        executeNextFunction()
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
        globalStack = [
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
            executeNextFunction()
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
        globalStack = [.disconnectDevice, .uploadDocument, .signDocument, .connectDevice]
        executeNextFunction()
    }
    
    // This function is called when the "Cancel" button has been pressed
    func cancelTransaction() {
        print("Cancel the transaction")
        processView.isHidden = false
        view.backgroundColor = UIColor.lightGray
        executeNextFunction()
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
    

    // BLUETOOTH RELATED ASPECTS

    // Viewed from the client (mobile device) perspective
    let UART_SERVICE_ID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    let UART_WRITE_ID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    let UART_NOTIFICATION_ID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

    // Creating blePeripheral object, notification characteristic, and write characteristic
    var blePeripheral : CBPeripheral?
    var notifyCharacteristic : CBCharacteristic? // UART_NOTIFICATION_ID
    var writeCharacteristic : CBCharacteristic? // UART_WRITE_ID
    var characteristicASCIIValue = NSString()
    
    // Create instance variables of the CBCentralManager
    var centralManager: CBCentralManager? // central manager object is the iphone device
    var bluetoothOffLabel = 0.0
    
    // These variables capture the state of the HSM proxy
    let BLEService_UUID = CBUUID(string: UART_SERVICE_ID)
    let BLE_Characteristic_uuid_Rx = CBUUID(string: UART_WRITE_ID)
    let BLE_Characteristic_uuid_Tx = CBUUID(string: UART_NOTIFICATION_ID)
    
    // Request and response related attributes
    var numBlocks : Int = 0
    var request : [UInt8]?
    var requestType : UInt8?
 
    // Timer for connecting to peripheral - will display "not connected" after 10 seconds if cannot find peripheral
    var isConnected = false
    
    /**
     * This function is called to start scanning for peripherals specifically with the correct services.
     */
    func startScan() {
        print("Now Scanning...")
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID] , options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { // the desired number of seconds delay
            // Code you want to be delayed
            if isConnected == false {
                ProgressHUD.showError("No Connection")
                stopScan()
            }
        }
    }
    
    /**
     * This function is called to stop scanning for peripherals.
     */
    func stopScan() {
        print("stopped scanning")
        centralManager!.stopScan()
    }
    
    /**
     * This function is connected to the "Connect" button to connect to the peripheral we found and will automatically
     * call the "didConnect" function below.
     */
    func connectToDevice() {
        print("Connecting to a device")
        connectCheckmark.isHidden = false
        centralManager?.connect(blePeripheral!, options: nil)
    }
    
    func disconnectFromDevice() {
        print("Disconnecting from the device")
        DisconnectDevice.isHidden = false
        if blePeripheral != nil {
            centralManager?.cancelPeripheralConnection(blePeripheral!)
            blePeripheral = nil
        }
        disconnectCheckmark.isHidden = false
        closeButton.isEnabled = true
        PayMerchant.isHidden = false
        EraseKeys.isHidden = false
    }
    
    // Size of blocks sent to peripheral. (512 - 2 = 510, to account for the two leading bytes which tell peripheral what to do
    let BLOCK_SIZE : Int = 510

    /**
     * This function formats a request into a binary format prior to sending it via bluetooth.
     * Each request has the following byte format:
     *   Request (1 byte) [0..255]
     *   Number of Arguments (1 byte) [0..255]
     *   Length of Argument 1 (2 bytes) [0..65535]
     *   Argument 1 ([0..65535] bytes)
     *   Length of Argument 2 (2 bytes) [0..65535]
     *   Argument 2 ([0..65535] bytes)
     *      ...
     *   Length of Argument N (2 bytes) [0..65535]
     *   Argument N ([0..65535] bytes)
     *
     * If the entire request is only a single byte long then the number of arguments
     * is assumed to be zero.
     
     * @param type A string representing the type of the request.
     * @param args Zero or more byte arrays containing the bytes for each argument.
     * @returns A byte array containing the bytes for the entire request.
     */
    func formatRequest(_ type : String, _ args : [UInt8]?...) -> [UInt8] {
        switch(type) {
        case "loadBlocks":
            requestType = 0
        case "generateKeys":
            requestType = 1
        case "rotateKeys":
            requestType = 2
        case "eraseKeys":
            requestType = 3
        case "digestBytes":
            requestType = 4
        case "signBytes":
            requestType = 5
        case "validSignature":
            requestType = 6
        default:
            print("Error: default in switch case")
        }
        request : [UInt8] = [requestType!, UInt8(args.count)]
        var length : Int
        for arg in args {
            length = arg!.count
            request += [UInt8(length >> 8), UInt8(length & 0xFF)] // the length of this argument
            request += arg! // the argument bytes
        }
        print("Request: \(request)")
        return request
    }
    
    /**
     * This function sends a request to a BLEUart service for processing (utilizing the processBlock function)
     *
     * Note: A BLEUart service can only handle requests up to 512 bytes in length. If the
     * specified request is longer than this limit, it is broken up into separate 512 byte
     * blocks and each block is sent as a separate BLE request.
     *
     * @param request A byte array containing the request to be processed.
     */
    func processRequest(_ request : [UInt8]) {
        var buffer : [UInt8]
        var offset : Int
        var blockSize : Int
        var temp : Double = Double(request.count - 2) / Double(BLOCK_SIZE)
        // refactor later to make numBlocks equivalent to numExtraBlocks and change according code
        numBlocks = Int(temp.rounded(.up))
        
        if numBlocks > 1 {
            print("NumBlocks: \(numBlocks)")
            // the offset includes the header bytes
            offset = (numBlocks - 1) * BLOCK_SIZE + 2
            
            // calculate the current block size
            blockSize = min(request.count - offset, BLOCK_SIZE)
            
            // concatenate a header and the current block bytes
            buffer = [0x00, UInt8(numBlocks - 1)] + Array(request[offset ..< (offset + blockSize)])
        } else {
            print("NumBlocks: \(numBlocks)")
            blockSize = min(request.count, BLOCK_SIZE + 2);
            buffer = Array(request[0..<blockSize])  // includes the actual header
        }
        numBlocks -= 1
        processBlock(buffer)
    }
    
    /**
     * Process a single block of the request.
     *
     * @param request A byte array containing the request to be processed.
     */
    func processBlock(_ val : [UInt8]) {
        let ns = NSData(bytes: val, length: val.count)
        print("Wrote Characteristic - Processed Block")
        blePeripheral!.writeValue(ns as Data, for: writeCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
    /**
     * This function is called to check that your device (iPhone) has bluetooth on
     *
     * @param request The CentralManager object representing the central (iPhone)
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("CentralManager is initialized")
        switch central.state {
        case .unknown:
            print("Bluetooth status is UNKNOWN")
            bluetoothOffLabel = 1.0
        case .resetting:
            print("Bluetooth status is RESETTING")
            bluetoothOffLabel = 1.0
        case .unsupported:
            print("Bluetooth status is UNSUPPORTED")
            bluetoothOffLabel = 1.0
        case .unauthorized:
            print("Bluetooth status is UNAUTHORIZED")
            bluetoothOffLabel = 1.0
        case .poweredOff:
            print("Bluetooth status is POWERED OFF")
            bluetoothOffLabel = 1.0
        case .poweredOn:
            print("Bluetooth status is POWERED ON")
            print("Start Scan")
            startScan()
        }
    }
    
    /**
     * This function is called after discovering the correct peripheral.
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        peripheral.delegate = self
        if blePeripheral == nil {
            print("We found a new pheripheral devices with services")
            print("Peripheral name: \(peripheral.name)")
            print("**********************************")
            print ("Advertisement Data : \(advertisementData)")
            blePeripheral = peripheral
        }
        executeNextFunction()
    }
    
    /**
     * After connecting, this function is automatically called
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        ProgressHUD.showSuccess("Welcome!")
        isConnected = true
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(blePeripheral)")
        
        //Stop Scan- We don't need to scan once we've connected to a peripheral. We got what we came for.
        stopScan()
        
        //Discovery callback
        peripheral.delegate = self
        //Only look for services that matches transmit uuid
        peripheral.discoverServices([BLEService_UUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            //looks for the right characteristic
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                writeCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                //                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                //                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
                
            }
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx) {
                notifyCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
                
                peripheral.setNotifyValue(true, for: notifyCharacteristic!)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                
                // peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if (error != nil) {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))")
            
        } else {
            print("Characteristic's value subscribed")
        }
        
        if (characteristic.isNotifying) {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
        executeNextFunction()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Update Value Call")
        if characteristic == notifyCharacteristic {
            let characteristicData = characteristic.value!
            print("Characteristic Data: \(characteristicData)")
            var byteArray = [UInt8](characteristicData)
            if byteArray.count > 0 {
                checkResponse(response : byteArray)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // the desired number of seconds delay
//            ProgressHUD.showError("Disconnected")
//        }
        print("Successfully Disconnected")
        EraseKeys.isEnabled = true
        PayMerchant.isEnabled = true
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
    
}
