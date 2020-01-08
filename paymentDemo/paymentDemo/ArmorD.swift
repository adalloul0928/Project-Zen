//
//  ArmorD.swift
//  paymentDemo
//
//  Created by Aren Dalloul on 8/23/19.
//  Copyright © 2019 Aren Dalloul. All rights reserved.
//

import Foundation


/*
 * This protocol defines the interface to an ArmorD peripheral device.
 */
protocol ArmorD {

    func processRequest(type: String, _ args: [UInt8]...)

}
