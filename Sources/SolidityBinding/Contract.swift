//
//  File.swift
//  Adapted from https://github.com/Boilertalk/Web3.swift/blob/master/Sources/ContractABI/Contract/ABIObject.swift

//
//
//  Created by Monterey on 19/3/22.
//

import Foundation

struct ContractJson: Codable {
    let abi: Contract
    let bytecode: String
    let contractName: String
}

typealias Contract = [ContractItem]

struct ContractItem: Codable {
    let inputs: [Parameter]?
    let outputs: [Parameter]?
    let payable: Bool?
    let stateMutability: StateMutability?
    let name: String?
    let type: ObjectType
    let anonymous: Bool?
    let constant: Bool?
    
    enum CodingKeys: String, CodingKey {
        case inputs = "inputs"
        case outputs = "outputs"
        case payable = "payable"
        case stateMutability = "stateMutability"
        case name = "name"
        case type = "type"
        case anonymous = "anonymous"
        case constant = "constant"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.constant = try container.decodeIfPresent(Bool.self, forKey: .constant) ?? false
        self.inputs = try container.decodeIfPresent([Parameter].self, forKey: .inputs)
        self.outputs = try container.decodeIfPresent([Parameter].self, forKey: .outputs)
        self.payable = try container.decodeIfPresent(Bool.self, forKey: .payable)
        self.stateMutability = try container.decodeIfPresent(StateMutability.self, forKey: .stateMutability)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.type = try container.decodeIfPresent(ObjectType.self, forKey: .type) ?? .function
        self.anonymous = try container.decodeIfPresent(Bool.self, forKey: .anonymous)
    }
}

enum StateMutability: String, Codable {
    case pure
    case view
    case nonpayable
    case payable
    
    var isConstant: Bool {
        return self == .pure || self == .view
    }
}

enum ObjectType: String, Codable {
    case event
    case function
    case constructor
    case fallback
    case receive
}

struct Parameter: Codable {
    let indexed: Bool?
    let internalType: String?
    let components: [Parameter]?
    let name: String
    let type: String
}
