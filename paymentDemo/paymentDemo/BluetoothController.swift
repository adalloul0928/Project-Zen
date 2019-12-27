//
//  BluetoothController.swift
//  paymentDemo
//
//  Created by Aren Dalloul on 8/23/19.
//  Copyright © 2019 Aren Dalloul. All rights reserved.
//

import UIKit
import CoreBluetooth
import Foundation
import AVKit
import AVFoundation


// ViewController class adopts both the central and peripheral delegates and conforms to their protocol requirements
class BluetoothController: CBCentralManagerDelegate, CBPeripheralDelegate {

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
    var centralManager : CBCentralManager?
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
    
    init() {
        // central manager object is the iphone device
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
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
        request = [requestType!, UInt8(args.count)]
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
        executeNextTask()
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
        executeNextTask()
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
