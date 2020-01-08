//
//  FlowControl.swift
//  paymentDemo
//
//  Created by Derk Norton on 1/6/20.
//  Copyright © 2020 Aren Dalloul. All rights reserved.
//

import Foundation

protocol FlowControl {
    func stepFailed(reason: String)
    func stepSucceeded(device: ArmorD, result: [UInt8]?)
}
