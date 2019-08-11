//
//  HSM.swift
//  BluefruitApp_Aren
//
//  Created by Addison Perrett on 8/9/19.
//  Copyright © 2019 Aren Dalloul. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

// Private Attributes
let PROTOCOL : String  = "v1"
let DIGEST : String = "sha512"
let SIGNATURE : String = "ed25519"
let BLOCK_SIZE : Int = 510
let KEY_SIZE : Int = 32
let DIG_SIZE : Int = 64
let SIG_SIZE : Int = 64

// Viewed from the client (mobile device) perspective
//let UART_SERVICE_ID : String = "6e400001b5a3f393e0a9e50e24dcca9e"
//let UART_WRITE_ID : String = "6e400002b5a3f393e0a9e50e24dcca9e"
//let UART_NOTIFICATION_ID : String = "6e400003b5a3f393e0a9e50e24dcca9e"

// These variables capture the state of the HSM proxy
//var Peripheral peripheral;
//var secret : [Int] // look for unsigned 8-bit int
//var previousSecret : [Int]

/**
 * This function generates a new public-private key pair.
 *
 * @returns A byte array containing the new public key.
 */

//func generateKeys() -> [Int]{
//    do {
//        if peripheral == null {
////            startScan()
//        }
//        secret = crypto.randomBytes(KEY_SIZE)
//        var request : [Int] = formatRequest("generateKeys", secret)
//        var publicKey : [Int] = processRequest(request)
//        return publicKey
//        } catch {
//            print("A new key pair could not be generated")
//        }
//    }
//}
//
//func formatRequest(type : String, args : Int...) -> [Int]{
//    switch(type) {
//        case "generateKeys":
//            type = 1
//        case "rotateKeys":
//            type = 2
//        case "eraseKeys":
//            type = 3
//        case "digestBytes":
//            type = 4
//        case "signBytes":
//            type = 5
//        case "validSignature":
//            type = 6
//    default:
//        print("Error: default in switch case")
//    }
//    var request : [Int]
//
//}
