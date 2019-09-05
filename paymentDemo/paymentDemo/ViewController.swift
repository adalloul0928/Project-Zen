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

// Viewed from the client (mobile device) perspective
let UART_SERVICE_ID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
let UART_WRITE_ID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
let UART_NOTIFICATION_ID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

let PROTOCOL : String  = "v1"
let DIGEST : String = "sha512"
let SIGNATURE : String = "ed25519"
let BLOCK_SIZE : Int = 510
let DIG_SIZE : Int = 64

let accountTagString = randomBytes(size: TAG_SIZE)

// ViewController class adopts both the central and peripheral delegates and conforms to their protocol's requirements
class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    // Creating blePeripheral object, notification characteristic, and write characteristic
    var blePeripheral : CBPeripheral?
    var notifyCharacteristic : CBCharacteristic? // UART_NOTIFICATION_ID
    var writeCharacteristic : CBCharacteristic? // UART_WRITE_ID
    var characteristicASCIIValue = NSString()
    var validSignatureBool : Bool = false
    
    // Create instance variables of the CBCentralManager and CBPeripheral
    var centralManager: CBCentralManager? // central manager object is the iphone device
    var bluetoothOffLabel = 0.0
    
    // Dummy variable to test signbytes
    var test = [UInt8](repeating: 0, count: KEY_SIZE)
    lazy var testStatus = SecRandomCopyBytes(kSecRandomDefault, KEY_SIZE, &test)
    
    // Dummy variable to test failure. Will delete later when not needed! Used for signatureValid
    var badtest = [UInt8](repeating: 0, count: KEY_SIZE)
    lazy var testBadStatus = SecRandomCopyBytes(kSecRandomDefault, KEY_SIZE, &badtest)
    
    // These variables capture the state of the HSM proxy
    var publicKey : [UInt8]?
    var secret = [UInt8](repeating: 0, count: KEY_SIZE)  // look for unsigned 8-bit int
    var previousSecret : [UInt8]?
    var signedBytes : [UInt8]? // equivalent to signature
    let BLEService_UUID = CBUUID(string: UART_SERVICE_ID)
    let BLE_Characteristic_uuid_Rx = CBUUID(string: UART_WRITE_ID)
    let BLE_Characteristic_uuid_Tx = CBUUID(string: UART_NOTIFICATION_ID)
    
    // Global variable to know what request we've made to check in func checkResponse()
    var REQUEST_TYPE : UInt8?
    
    // Timer for connecting to peripheral - will display "not connected" after 10 seconds if cannot find peripheral
    var connected = false
    
    // To save the generated key
    let defaults = UserDefaults.standard
    var savedPublicValue : [UInt8]?
    var savedSecret : [UInt8]?
    
    // Generate document and certificate
    let accountTag = randomBytes(size: TAG_SIZE)
//    let certificate = generateCertificate(accountTag: accountTag, publicKey: publicKey)
    
    // State of the application to direct what function to do next
    var appState = 0
    var numBlocks : Int = 0
    var signBytesRequest : [UInt8]?
 
    var alertMessage : String?
    
    struct Keys {
        static let savedPublicKey = "savedPublicKey"
        static let savedPrivateKey = "savedPrivateKey"
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        checkForKeys()
    }
    

    @IBOutlet weak var PayMerchant: UIButton!
    
    @IBAction func TEST(_ sender: UIButton) {
        appState = 10
        connectToDevice()
    }
    
    @IBAction func buttonPressed(_ sender: UIButton) {
        appState = 2
        checkState(appState)
    }
    
    func generateAlertString(){
        // finish implementation
        var merchants : [String] = ["Starbucks", "BestBuy", "Target", "Hooters"]
        var amounts : [Float] = [7.99, 4.99, 5.00, 1.14]
        var randomIntMerchant = Int.random(in: 1..<4)
        var randomFloatPrice = Int.random(in: 1..<4)
        var merchant : String = merchants[randomIntMerchant]
        var amount : Float = amounts[randomFloatPrice]
        var tagIndex = accountTag.index(accountTag.startIndex, offsetBy: 8)
        let accountIDSubstring = accountTag[..<tagIndex]
        var date = Date()
        let formatter = DateFormatter()
        
        formatter.dateFormat = "dd.MM.yyyy"
        var dateFormatted : String = formatter.string(from: date)
        
        alertMessage = """
        AccountId: \(accountIDSubstring)
        Merchant: \(merchant)
        Date: \(dateFormatted)
        Time: 11:30:00 AM
        Amount: $\(amount)
        """
    }
    
    func checkState(_ currentState: Int){
        switch(currentState) {
        case 0:
            // update
            print("Searching for Peripheral")
        case 1:
            // update
            print("Found Peripheral")
        case 2:
            // update
            print("Active State - Connect to Device")
            connectToDevice()
        case 3:
            // State to check if have keys or need to generate new ones
            print("Connected - Check for Keys")
            if self.publicKey == nil{
                print("public key is nil")
                print(self.publicKey)
                appState = 4
            }
            else{
                print("Current Key: \(self.publicKey)")
                appState = 5
            }
            checkState(appState)
        case 4:
            // State to generate new keys
            print("Generating Keys")
            self.generateKeys()
        case 5:
            // Keys are generated, activate payment alert to user
            print("Keys Generated - Waiting for User to press Pay")
            self.generateAlertString()
            self.generateAlert(alertMessage!)
        case 6:
            // State where we can now call the signBytes function
            print("Signing Bytes")
            let publicKeyString = base32Encode(bytes : publicKey!)
            var certificate = generateCertificate(accountTag: accountTagString, publicKey: publicKeyString)
            let certificateBytes: [UInt8] = Array(certificate.utf8)
            print("Certificate: \(certificateBytes)")
            self.signBytes(certificateBytes)
        case 7:
            // Failed, for any number of numerous reasons. Need to update so not a catch all
            print("Failure")
            appState = 8
            checkState(appState)
        case 8:
            // Finished work, now need to disconnect
            print("Disconnecting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change `10.0` to the desired number of seconds.
                self.disconnectFromDevice()
            }
        case 9:
            // testing
            print("Processing Blocks - Checker")
            processRequest(signBytesRequest!)
        case 10:
            print("Erasing Keys")
            savedPublicValue = nil
            savedSecret = nil
            publicKey = nil
            saveSecretKeyValue()
            savePublicKeyValue()
            self.eraseKeys()
        default:
            print("Error: default in checkState")
        }
    }
    
    
    func checkResponse(response : [UInt8]){
        if response[0] == 255{
            print("Case \(REQUEST_TYPE): Failed 255")
        }
        else{
            switch(REQUEST_TYPE) {
            case 0:
                print("CASE Processing Blocks - NEED TO IMPLEMENT")
                appState = 9
            case 1:
                print("Generate Keys: ")
                if response.count == 32{
                    publicKey = response
                    savedPublicValue = publicKey
                    savedSecret = secret
                    savePublicKeyValue()
                    saveSecretKeyValue()
                    print("Public Key: \(publicKey)")
                    print("Secret: \(secret)")
                    appState = 5
                }
                else{
                    print("Generate Keys Failed")
                    appState = 7
                }
            case 2:
                // Add in saving default values
                print("Rotate Keys: ")
                if response.count == 32{
                    publicKey = response
                    print("New Public Key: \(publicKey)")
                }
                appState = 8
            case 3:
                print("Erase Keys: ")
                if response[0] == 1{
                    print("SUCCESS")
                }
                else if response[1] == 0{
                    print("Did Not Erase Keys")
                }
                appState = 8
            case 4:
                print("CASE Digest Bytes - NEED TO IMPLEMENT")
                appState = 8
            case 5:
                print("Sign Bytes: ")
                if response.count == 64{
                    signedBytes = response
                    print("Signed Bytes: \(signedBytes)")
                    ProgressHUD.showSuccess("Payment Success")
                    appState = 8
                }
                else{
                    ProgressHUD.showError("Payment Failed")
                    appState = 8
                }
            case 6:
                print("Signature Valid: ")
                if response[0] == 1{
                    validSignatureBool = true // may not need??
                    print("IsValid Signature")
                    appState = 8
                }
                else if response[1] == 0{
                    print("Signature NOT Valid")
                    appState = 8
                }
                
            default:
                print("Error: default in switch case")
                print("Response: \(response)")
                appState = 7
            }
            checkState(appState)
        }
    }
    
    
    /**
     * This function generates a new public-private key pair.
     */
    func generateKeys(){
        do {
            if blePeripheral == nil {
                print("Not Connected to Device")
                // FIX TO THROW ERROR IF NOT CONNECTED TO DEVICE
            }
            let status = SecRandomCopyBytes(kSecRandomDefault, KEY_SIZE, &secret)
            if status == errSecSuccess { // Always test the status.
                print(secret)
                // Prints something different every time you run.
            }
            var request : [UInt8] = formatRequest("generateKeys", secret)
            processRequest(request)
        } catch {
            print("A new key pair could not be generated")
        }
    }
    
    
    /**
     * This function replaces the existing public-private key pair with a new one.
     *
     * @returns A byte array containing the new public key.
     */
    func rotateKeys() {
        previousSecret = secret
        SecRandomCopyBytes(kSecRandomDefault, KEY_SIZE, &secret)
        var request : [UInt8] = formatRequest("rotateKeys", previousSecret, secret)
        processRequest(request)
    }
    
    
    /**
     * This function deletes any existing public-private key pairs.
     *
     * @returns Whether or not the keys were successfully erased.
     */
    func eraseKeys(){
        var request : [UInt8] = formatRequest("eraseKeys")
        processRequest(request)
    }
    
    
    /**
     * This function generates a digital signature of the specified bytes using
     * the current private key (or the old private key, one time only, if it exists).
     * This allows a new certificate to be signed using the previous private key.
     * The resulting digital signature can then be verified using the corresponding
     * public key.
     *
     * @param bytes A byte array containing the bytes to be digitally signed.
     * @returns A byte array containing the resulting digital signature.
     */
    func signBytes(_ bytes : [UInt8]) {
//        var request : [UInt8]
        if (previousSecret != nil) {
            // we are in the process of rotating keys so use the previous secret
//            request = formatRequest("signBytes", previousSecret, bytes)
            signBytesRequest = formatRequest("signBytes", previousSecret, bytes)
            previousSecret = nil
        } else {
            signBytesRequest = formatRequest("signBytes", secret, bytes)
        }
        processRequest(signBytesRequest!)
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
        var request : [UInt8] = formatRequest("validSignature", aPublicKey, signature, bytes)
        processRequest(request)
    }
    
    
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
    func formatRequest(_ type : String, _ args : [UInt8]?...) -> [UInt8]{
        switch(type) {
        case "loadBlocks":
            REQUEST_TYPE = 0
        case "generateKeys":
            REQUEST_TYPE = 1
        case "rotateKeys":
            REQUEST_TYPE = 2
        case "eraseKeys":
            REQUEST_TYPE = 3
        case "digestBytes":
            REQUEST_TYPE = 4
        case "signBytes":
            REQUEST_TYPE = 5
        case "validSignature":
            REQUEST_TYPE = 6
        default:
            print("Error: default in switch case")
        }
        var request : [UInt8] = [REQUEST_TYPE!, UInt8(args.count)]
        var length : Int
        for arg in args{
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
    func processRequest(_ request : [UInt8]){
        var buffer : [UInt8]
        var offset : Int
        var blockSize : Int
        var temp : Double = Double(request.count - 2) / Double(BLOCK_SIZE)
        // refactor later to make numBlocks equivalent to numExtraBlocks and change according code
        numBlocks = Int(temp.rounded(.up))
        
        if numBlocks > 1{
            print("NumBlocks: \(numBlocks)")
            // the offset includes the header bytes
            offset = (numBlocks - 1) * BLOCK_SIZE + 2
            
            // calculate the current block size
            blockSize = min(request.count - offset, BLOCK_SIZE)
            
            // concatenate a header and the current block bytes
            buffer = [0x00, UInt8(numBlocks - 1)] + Array(request[offset ..< (offset + blockSize)])
        }
        else{
            print("NumBlocks: \(numBlocks)")
            blockSize = min(request.count, BLOCK_SIZE + 2);
            buffer = Array(request[0..<blockSize])  // includes the actual header
        }
        numBlocks -= 1
        processBlock(buffer)
    }
    
    
    /**
     * REMOVE - only need the writeCharacteristic block
     *
     * @param request A byte array containing the request to be processed.
     */
    func processBlock(_ val : [UInt8]){
        let ns = NSData(bytes: val, length: val.count)
        print("Wrote Characteristic - Processed Block")
        blePeripheral!.writeValue(ns as Data, for: writeCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
    
    /**
     * This function writes the block to the peripheral device.
     *
     * @param request A byte array containing the request to be processed.
     */
//    func writeCharacteristic(val: [UInt8]){
//        let ns = NSData(bytes: val, length: val.count)
//        print("Wrote Characteristic")
//        blePeripheral!.writeValue(ns as Data, for: writeCharacteristic!, type: CBCharacteristicWriteType.withResponse)
//    }
    
    
    /**
     * This function is called to check that your device (iPhone) has bluetooth on
     *
     * @param request The CentralManager object representing the central (iPhone)
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager){
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
     * This function is called to start scanning for peripherals specifically with the correct services.
     */
    func startScan() {
        print("Now Scanning...")
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID] , options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { // Change `10.0` to the desired number of seconds.
            // Code you want to be delayed
            if self.connected == false{
                ProgressHUD.showError("No Connection")
                self.stopScan()
            }
        }
    }
    
    
    /**
     * This function is called to stop scanning for peripherals.
     */
    func stopScan(){
        print("stopped scanning")
        centralManager!.stopScan()
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
        appState = 1
    }
    
    
    /**
     * This function is connected to the "Connect" button to connect to the peripheral we found and will automatically
     * call the "didConnect" function below.
     */
    func connectToDevice() {
        centralManager?.connect(blePeripheral!, options: nil)
    }
    
    
    /**
     * After connecting, this function is automatically called
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        ProgressHUD.showSuccess("Connected")
        connected = true
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
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
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
        if appState != 10{
            appState = 3
        }
        checkState(appState)
    }


    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Update Value Call")
        if characteristic == notifyCharacteristic {
            let characteristicData = characteristic.value!
            print("Characteristic Data: \(characteristicData)")
            var byteArray = [UInt8](characteristicData)
            if byteArray.count > 0{
                checkResponse(response : byteArray)
            }
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Change `10.0` to the desired number of seconds.
            ProgressHUD.showError("Disconnected")
        }
        print("Successfully Disconnected")
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
    
    
    func disconnectFromDevice() {
        if blePeripheral != nil {
            centralManager?.cancelPeripheralConnection(blePeripheral!)
        }
        appState = 2
    }
    
    
    func payTheBill(){
//        let buf: [UInt8] = Array("test".utf8)
        print("Paid the Bill")
        appState = 6
        checkState(appState)
    }
    
    
    func generateAlert (_ alertMessage: String){
        let alert = UIAlertController(title: "Pay Merchant", message: alertMessage, preferredStyle: .alert)
        let payAction = UIAlertAction(title: "Pay", style: .default, handler: { (UIAlertAction) in self.payTheBill()})
        let cancelPayment = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil)
        
        alert.addAction(payAction)
        alert.addAction(cancelPayment)
        
        present(alert, animated: true, completion: nil)
    }
    
    
    func savePublicKeyValue() {
        print("Saved Public Key Value")
        print("savedPublicValue: \(savedPublicValue)")
        defaults.set(savedPublicValue, forKey: Keys.savedPublicKey)
    }
    
    func saveSecretKeyValue(){
        print("Saved Secret Key Value")
        print("savedSecretValue: \(savedSecret)")
        defaults.set(savedSecret, forKey: Keys.savedPrivateKey)
    }
    
    
    func checkForKeys() {
        let possibleSavedKey = defaults.array(forKey: Keys.savedPublicKey)
        let possibleSavedSecret = defaults.array(forKey: Keys.savedPrivateKey)
        
        if possibleSavedKey != nil{
            publicKey = possibleSavedKey as! [UInt8]
            secret = possibleSavedSecret as! [UInt8]
        }
        print("Check for Public Key: \(publicKey)")
        print("Check for Secret Device Key: \(secret)")
    }
}

