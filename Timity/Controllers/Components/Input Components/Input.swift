//
//  Input.swift
//  Timity
//
//  Created by Andreas Link on 2/12/18.
//  Copyright © 2018 Andreas Link. All rights reserved.
//

import Foundation

enum InputType {
    case eventListResult
    case eventCalculatorResult
    case timeCalculatorResult
    case durationCalculatorResult
    case solarCalculatorResult
}

struct Input {
    var type:InputType
    var data:[Any?]
}
