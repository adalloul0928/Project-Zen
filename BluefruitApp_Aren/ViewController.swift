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
var txCharacteristic : CBCharacteristic?
var rxCharacteristic : CBCharacteristic?
var characteristicASCIIValue = NSString()
let UART_SERVICE_ID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
let UART_WRITE_ID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
let UART_NOTIFICATION_ID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

// ViewController class adopts both the central and peripheral delegates and conforms to their protocol's requirements
class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // Create instance variables of the CBCentralManager and CBPeripheral
    var centralManager: CBCentralManager?
    var buttonUpPeripheral = [CBPeripheral]()
    var bluetoothOffLabel = 0.0
    var RSSIs = [NSNumber()]
    let BLEService_UUID = CBUUID(string: UART_SERVICE_ID)
    let BLE_Characteristic_uuid_Rx = CBUUID(string: UART_WRITE_ID)
    let BLE_Characteristic_uuid_Tx = CBUUID(string: UART_NOTIFICATION_ID)
    
    
    @IBAction func connectButton(_ sender: UIButton) {
        connectToDevice()
    }
    
    @IBAction func disconnectButton(_ sender: UIButton) {
        disconnectFromDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
        self.buttonUpPeripheral.append(peripheral)
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
        
//    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
//
//        if characteristic == rxCharacteristic {
//            if let ASCIIstring = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue) {
//                characteristicASCIIValue = ASCIIstring
//                print("Value Recieved: \((characteristicASCIIValue as String))")
//                NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: nil)
//            }
//        }
//    }
    
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

