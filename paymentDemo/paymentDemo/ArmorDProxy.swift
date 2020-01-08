//
//  ArmorDProxy.swift
//  paymentDemo
//
//  Copyright © 2019 Aren Dalloul. All rights reserved.
//

import Foundation
import CoreBluetooth


// This class acts as a proxy to an ArmorD device that supports bluetooth low energy (BLE).
class ArmorDProxy: NSObject, ArmorD, CBCentralManagerDelegate, CBPeripheralDelegate {

    // PUBLIC INTERFACE

    init(controller: FlowControl) {
        self.controller = controller
        super.init()  // must be called before next line which passes self in as an argument
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /*
     * This function sends a request to a BLEUart service for processing (utilizing the processBlock function)
     *
     * Note: A BLEUart service can only handle requests up to 512 bytes in length. If the
     * specified request is longer than this limit, it is broken up into separate 512 byte
     * blocks and each block is sent as a separate BLE request.
     */
    func processRequest(type: String, _ args: [UInt8]...) {
        print("Processing a request of type: \(type)")

        // decode the request type
        var requestType: UInt8 = 255  // set to an invalid type
        switch(type) {
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
            print("Error: Invalid request type: \(type)")
        }

        // assemble the request type and number of arguments as the first two bytes of the request
        request = [UInt8]()  // reset the request buffer
        request += [requestType, UInt8(args.count)]

        // add the length of each argument as two bytes followed by the argument bytes for each argument
        for arg in args {
            let length: Int = arg.count
            request += [UInt8(length >> 8), UInt8(length & 0xFF)] // the length of this argument
            request += arg // the argument bytes
        }

        // the request is fully assembled
        print("Request: \(request)")
        
        // calculate the current block number (first block is zero)
        block = Int((Double(request.count - 2) / Double(BLOCK_SIZE)).rounded(.up)) - 1

        // process the first (and perhaps only) block
        connect()
    }
    
    // PRIVATE INTERFACE

    // The BLE central manager proxy (iPhone App)
    var centralManager: CBCentralManager!
    
    // The BLE peripheral proxy (ArmorD device)
    let BLE_Service_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    var blePeripheral: CBPeripheral?

    // The BLE peripheral RX characteristic (central manager writes to peripheral's UART RX line)
    let BLE_CharacteristicWrite_UUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    var writeCharacteristic: CBCharacteristic?

    // The BLE peripheral TX characteristic (peripheral's notifies central manager using UART TX line)
    let BLE_CharacteristicNotify_UUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    var notifyCharacteristic: CBCharacteristic?
    
    // A reference to the flow controller via the FlowControl protocol
    var controller: FlowControl
 
    // The size of the data blocks sent to the peripheral which is 512 - 2 = 510, to account for the
    // two leading bytes which tell the peripheral the request type (1 byte) and number of
    // arguments (1 byte)
    let BLOCK_SIZE = 510
    
    // The request buffer and number of blocks
    var request = [UInt8]()  // empty array of bytes
    var block = 0

    /*
     * This function is called when the mobile device bluetooth status changes.
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("CentralManager is initialized")
        switch central.state {
        case .unknown:
            print("Bluetooth status is UNKNOWN")
        case .resetting:
            print("Bluetooth status is RESETTING")
        case .unsupported:
            print("Bluetooth status is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth status is UNAUTHORIZED")
        case .poweredOff:
            print("Bluetooth status is POWERED OFF")
        case .poweredOn:
            print("Bluetooth status is POWERED ON")
        @unknown default:
            print("Bluetooth status is \(central.state)")
        }
    }
    
    /*
     * This function attempts to connect to an ArmorD peripheral
     */
    func connect() {
        print("Connecting to an ArmorD peripheral...")
        startScanning()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { // wait 10 seconds
            if self.blePeripheral == nil {
                print("Unable to locate an ArmorD peripheral.")
                self.stopScanning()
            }
        }
    }
    
    /*
     * Disconnect from the ArmorD peripheral
     */
    func disconnect() {
        print("Disconnecting from the ArmorD peripheral...")
        centralManager!.cancelPeripheralConnection(blePeripheral!)
    }

    /*
     * This function is called to start scanning for peripherals that support the correct services.
     */
    func startScanning() {
        print("Now Scanning...")
        centralManager!.scanForPeripherals(withServices: [BLE_Service_UUID] , options: nil)
    }
    
    /*
     * This function is called to stop scanning for peripherals.
     */
    func stopScanning() {
        print("Stopped scanning for peripherals.")
        centralManager!.stopScan()
    }
    
    /*
     * This function processes a single block of the current request.
     */
    func processBlock() {
        var buffer: [UInt8], length: Int;
        print("Processing block: \(block)")
        if (block > 0) {
            // the offset includes the header bytes
            let offset = block * BLOCK_SIZE + 2
            
            // calculate the current block size
            length = min(request.count - offset, BLOCK_SIZE)
            
            // concatenate a header and the current block bytes
            buffer = [0x00, UInt8(block)] + Array(request[offset ..< (offset + length)])
        } else {
            // calculate the size of the first block
            length = min(request.count, BLOCK_SIZE + 2)

            // load the first block into the buffer
            buffer = Array(request[0..<length])  // includes the actual header
        }
        block -= 1  // decrement the block count
        let data = NSData(bytes: buffer, length: buffer.count)
        blePeripheral!.writeValue(data as Data, for: writeCharacteristic!, type: CBCharacteristicWriteType.withResponse)
        print("\(buffer.count) bytes were written to the ArmorD device.")
    }

    /*
     * This function is called when a peripheral has been discovered
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = String(describing: peripheral.name)
        print("The following peripheral was found:")
        print("  name: \(name)")
        print("  advertisement: \(advertisementData)")
        peripheral.delegate = self
        blePeripheral = peripheral
    }
    
    /*
     * This function is called each time a peripheral has been connected
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(String(describing: peripheral))")
        stopScanning()
        peripheral.delegate = self
        peripheral.discoverServices([BLE_Service_UUID]) // triggers didDiscoverServicesFor
    }
    
    /*
     * This function is called each time the peripheral has been disconnected
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        controller.stepSucceeded(device: self, result: nil)
        guard error == nil else {
            let reason = String(describing: error!.localizedDescription)
            print("Error disconnecting peripheral: \(reason)")
            return
        }
        print("Disconnected from peripheral: \(String(describing: peripheral))")
    }
    
    /*
     * This function is called each time a request was sent to the peripheral
     */
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            let reason = String(describing: error!.localizedDescription)
            print("Error sending request: \(reason)")
            disconnect()
            controller.stepFailed(reason: reason)
            return
        }
        print("Request sent.")
    }
    
    /*
     * This function is called each time peripheral services are discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            let reason = String(describing: error!.localizedDescription)
            print("Error discovering services: \(reason)")
            disconnect()
            controller.stepFailed(reason: reason)
            return
        }
        guard let services = peripheral.services else {
            // No services found, keep trying...
            return
        }
        print("Found \(services.count) services.")
        for service in services {
            print("Found service: \(service.uuid)")
            if service.uuid.isEqual(BLE_Service_UUID)  {
                peripheral.discoverCharacteristics(nil, for: service) // triggers didDiscoverCharacteristicsFor
            }
        }
    }
    
    /*
     * This function is called each time characteristics for a peripheral service are discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            let reason = String(describing: error!.localizedDescription)
            print("Error discovering characteristics: \(reason)")
            disconnect()
            controller.stepFailed(reason: reason)
            return
        }
        guard let characteristics = service.characteristics else {
            // No characteristics found, keep trying...
            return
        }
        print("Found \(characteristics.count) characteristics.")
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(BLE_CharacteristicWrite_UUID)  {
                print("Found write characteristic: \(characteristic.uuid)")
                writeCharacteristic = characteristic
            } else if characteristic.uuid.isEqual(BLE_CharacteristicNotify_UUID) {
                print("Found notify characteristic: \(characteristic.uuid)")
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: notifyCharacteristic!) // triggers didUpdateNotificationStateFor
            }
        }
    }
    
    /*
     * This function is called each time the notification state on the ArmorD peripheral service changes
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            let reason = String(describing: error!.localizedDescription)
            print("Error changing notification state:\(reason)")
            disconnect()
            controller.stepFailed(reason: reason)
            return
        }
        guard characteristic.isNotifying else {
            let reason = "Can't notify"
            print("Error changing notification state:\(reason)")
            disconnect()
            controller.stepFailed(reason: reason)
            return
        }
        let uuid = characteristic.uuid
        print ("Notification has begun for: \(uuid)")
        processBlock() // triggers didUpdateValueFor
    }

    /*
     * This function is called each time a response is received from the ArmorD peripheral
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("A response was received from the ArmorD peripheral.")
        if characteristic == notifyCharacteristic {
            let characteristicData = characteristic.value!
            print("Characteristic Data: \(characteristicData)")
            let byteArray = [UInt8](characteristicData)
            if byteArray.count == 1 && byteArray[0] > 1 {
                print("ArmorD rejected the request.")
                disconnect()
                controller.stepFailed(reason: "ArmorD rejected the request with a status: \(byteArray[0])")
            } else {
                if block < 0 {
                    print("ArmorD completed the request.")
                    disconnect()
                    controller.stepSucceeded(device: self, result: byteArray)
                } else {
                    print("ArmorD is ready for the next block of the request.")
                    processBlock() // triggers another didUpdateValueFor
                }
            }
        }
    }

}
