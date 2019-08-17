//
//  ViewController.swift
//  BluefruitApp_Aren
//
//  Created by Addison Perrett on 8/8/19.
//  Copyright © 2019 Aren Dalloul. All rights reserved.
//

import UIKit
// Import CoreBluetooth for BLE functionality
import CoreBluetooth
import Foundation

var blePeripheral : CBPeripheral?
var txCharacteristic : CBCharacteristic? // UART_NOTIFICATION_ID
var rxCharacteristic : CBCharacteristic? // UART_WRITE_ID
var characteristicASCIIValue = NSString()

// Viewed from the client (mobile device) perspective
let UART_SERVICE_ID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
let UART_WRITE_ID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
let UART_NOTIFICATION_ID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

let PROTOCOL : String  = "v1"
let DIGEST : String = "sha512"
let SIGNATURE : String = "ed25519"
let BLOCK_SIZE : Int = 510
let KEY_SIZE : Int = 32
let DIG_SIZE : Int = 64
let SIG_SIZE : Int = 64

// ViewController class adopts both the central and peripheral delegates and conforms to their protocol's requirements
class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // Create instance variables of the CBCentralManager and CBPeripheral
    var centralManager: CBCentralManager?
    var peripherals_list = [CBPeripheral]()
    var bluetoothOffLabel = 0.0
    var RSSIs = [NSNumber()]
    var dataString : String?
    
    // These variables capture the state of the HSM proxy
    var secret = [UInt8](repeating: 0, count: KEY_SIZE)  // look for unsigned 8-bit int
    var previousSecret : [UInt8]?
    let BLEService_UUID = CBUUID(string: UART_SERVICE_ID)
    let BLE_Characteristic_uuid_Rx = CBUUID(string: UART_WRITE_ID)
    let BLE_Characteristic_uuid_Tx = CBUUID(string: UART_NOTIFICATION_ID)
    
    
    @IBAction func connectButton(_ sender: UIButton) {
        connectToDevice()
    }
    
    @IBAction func disconnectButton(_ sender: UIButton) {
        disconnectFromDevice()
    }
    
    @IBAction func GenerateKeys(_ sender: UIButton) {
        generateKeys()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    
    /**
     * This function generates a new public-private key pair.
     *
     * @returns A byte array containing the new public key.
     */
    
    func generateKeys(){
        do {
            if blePeripheral == nil {
                //            startScan()
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

    func formatRequest(_ type : String, _ args : [UInt8]?...) -> [UInt8]{
        var GENERATE_KEYS : UInt8?
        switch(type) {
            case "loadBlocks":
                GENERATE_KEYS = 0
            case "generateKeys":
                GENERATE_KEYS = 1
            case "rotateKeys":
                GENERATE_KEYS = 2
            case "eraseKeys":
                GENERATE_KEYS = 3
            case "digestBytes":
                GENERATE_KEYS = 4
            case "signBytes":
                GENERATE_KEYS = 5
            case "validSignature":
                GENERATE_KEYS = 6
        default:
            print("Error: default in switch case")
        }
        var request : [UInt8] = [GENERATE_KEYS!, UInt8(args.count)]
        var length : Int
        for arg in args{
            length = arg!.count
            request += [UInt8(length) >> 8, UInt8(length)]  // the length of this argument
            request += arg! // the argument bytes
        }
        print("Request: \(request)")
        return request
    }
    
    func processRequest(_ request : [UInt8]){
        var buffer : [UInt8]
        var offset : Int
        var blockSize : Int
        var temp : Double = Double(request.count - 2) / Double(BLOCK_SIZE) - 1
        var extraBlocks : Int = Int(temp.rounded(.up))
        var block : Int = extraBlocks

        while block > 0{
            // the offset includes the header bytes
            offset = block * BLOCK_SIZE + 2

            // calculate the current block size
            blockSize = min(request.count - offset, BLOCK_SIZE)

            // concatenate a header and the current block bytes
            buffer = [0x00, UInt8(block)] + Array(request[offset ..< (offset + blockSize)])

            // process the block and ignore the response
            processBlock(buffer)

            // move on to previous block
            block -= 1
        }
        blockSize = min(request.count, BLOCK_SIZE + 2);
        buffer = Array(request[0..<blockSize])  // includes the actual header
        var response = processBlock(buffer)
        return response
    }

    func processBlock(_ block : [UInt8]){
        writeCharacteristic(val: block)
//        var response = readCharacteristic()
    }

//    func readCharacteristic() -> [UInt8]{
//        blePeripheral?.readValue(for: txCharacteristic!)
//        var readCharacteristic : [UInt8] = UInt8(txCharacteristic!.value!)
//        return readCharacteristic
//    }

    func writeCharacteristic(val: [UInt8]){
        var val = val
        let ns = NSData(bytes: &val, length: val.count)
        print("here")
        blePeripheral!.writeValue(ns as Data, for: rxCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
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
    
    
    func startScan() {
        print("Now Scanning...")
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID] , options: nil)
    }
    
    func stopScan(){
        print("stopped scanning")
        centralManager!.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        stopScan()
        self.peripherals_list.append(peripheral)
        self.RSSIs.append(RSSI)
        peripheral.delegate = self
        if blePeripheral == nil {
            print("We found a new pheripheral devices with services")
            print("Peripheral name: \(peripheral.name)")
            print("**********************************")
            print ("Advertisement Data : \(advertisementData)")
            blePeripheral = peripheral
        }
    }
    
    func connectToDevice() {
        centralManager?.connect(blePeripheral!, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(blePeripheral)")
        
        //Stop Scan- We don't need to scan once we've connected to a peripheral. We got what we came for.
        centralManager?.stopScan()
        print("Scan Stopped")
        
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
                rxCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
//            peripheral.discoverDescriptors(for: characteristic)
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
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == txCharacteristic {
            var data = characteristic.value
            dataString = String(data: data!, encoding: String.Encoding.utf8)!
            print("Value Recieved: \(dataString)")
            }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Succeeded!")
    }
    
    func disconnectFromDevice () {
        if blePeripheral != nil {
            centralManager?.cancelPeripheralConnection(blePeripheral!)
        }
    }

}

