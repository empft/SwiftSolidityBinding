//
//  Codegen.swift
//  
//
//  Created by Monterey on 20/3/22.
//

import Foundation

private let unnamed = "unnamed"
private let dictResult = "result"

private extension Parameter {
    var isArray: Bool {
        return self.type.hasSuffix("]")
    }
}

private func isFixedArray(_ type: String) -> Bool {
    guard type.hasSuffix("]") else {
        preconditionFailure("Must be an array")
    }
    
    return !type.hasSuffix("[]")
}

private func arrayLength(_ type: String) -> String {
    guard type.hasSuffix("]") else {
        preconditionFailure("Must be an array")
    }
    
    // expected type to be form of name[] or name[12]
    let separated = type.components(separatedBy: "[")[1].dropLast()
    if let number = Int(separated) {
        return String(number)
    } else {
        return "nil"
    }
}

// non tuple
private func toLocalType(_ type: String) -> String {
    guard !type.contains("tuple") else {
        preconditionFailure("Must not be tuple type")
    }
    // if is array
    if type.hasSuffix("]") {
        return "[\(toLocalType(type.components(separatedBy: "[")[0]))]"
    } else if type.hasPrefix("int") {
        if type.hasSuffix("8") {
            return "Int8"
        } else if type.hasSuffix("16") {
            return "Int16"
        } else if type.hasSuffix("32") {
            return "Int32"
        } else if type.hasSuffix("64") {
            return "Int64"
        } else {
            return "BigInt"
        }
    } else if type.hasPrefix("uint") {
        if type.hasSuffix("8") {
            return "UInt8"
        } else if type.hasSuffix("16") {
            return "UInt16"
        } else if type.hasSuffix("32") {
            return "UInt32"
        } else if type.hasSuffix("64") {
            return "UInt64"
        } else {
            return "BigUInt"
        }
    } else if type == "bool" {
        return "Bool"
    } else if type == "address" {
        return "EthereumAddress"
    } else if type.hasPrefix("bytes") {
        return "Data"
    } else if type == "string" {
        return "String"
    } else {
        fatalError("Unimplemented type: \(type)")
    }
}

// non tuple, non array
private func toSolidityType(_ type: String) -> String {
    guard !type.contains("tuple") && !type.hasSuffix("]") else {
        preconditionFailure("Must not be tuple or array type")
    }
    
    let bytes = "bytes"
    if type.hasPrefix(bytes) {
        let length = type.count != bytes.count ? type.dropFirst(bytes.count) : "nil"
        return "bytes(length: \(length))"
    } else {
        return type
    }
}

private func formatIndexed(_ indexed: Bool?) -> String {
    if let indexed = indexed {
        return """
        , indexed: \(indexed)
        """
    } else {
        return ""
    }
}

/// Generate parameter type for parameter array
/// Example:
/// .address
private func generateParameterArrayType(_ parameter: Parameter) -> String {
    if let components = parameter.components {
        var tuple = ""
        for (index, component) in components.enumerated() {
            if index != 0 {
                tuple += ", "
            }
            tuple += generateParameterArrayType(component)
        }
        
        if parameter.isArray {
            return ".array(type: .tuple([\(tuple)]), length: \(arrayLength(parameter.type)))"
        } else {
            return ".tuple([\(tuple)])"
        }
    } else {
        if parameter.isArray {
            return ".array(type: .\(toSolidityType(String(parameter.type.dropLast(2)))), length: \(arrayLength(parameter.type)))"
        } else {
            return ".\(toSolidityType(parameter.type))"
        }
    }
}

/// Generate array of parameter recursively
/// Example:
/// .init(name: "_from", type: .address), .init(name: "_to", type: .address), .init(name: "_value", type: .uint256)
private func generateParameterArray(_ parameters: [Parameter], unnamedParamCount: Int = 0) -> String {
    var newParamCount = unnamedParamCount
    var text = ""
    for (index, parameter) in parameters.enumerated() {
        if index != 0 {
            text += ", "
        }
        
        var name = parameter.name
        if parameter.name.isEmpty {
            name = "\(unnamed)\(newParamCount)"
            newParamCount += 1
        }
        
        text += """
        .init(name: "\(name)", type: \(generateParameterArrayType(parameter))\(formatIndexed(parameter.indexed))
        """
        //is tuple
        if let components = parameter.components {
            text += ", components: [\(generateParameterArray(components, unnamedParamCount: newParamCount))]"
        }
        
        text += """
        )
        """
    }
    return text
}

/// Generate static variable event
private func generateEvent(_ item: ContractItem) -> String {
    var text: [String] = []
    text.append("""
    static var \(item.name!): SolidityTypedEvent<
    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        if inputs.count == 1 && inputs[0].components == nil {
            text.append("""
            \(toLocalType(inputs[0].type))
            """)
        } else {
            text.append("""
            (\(generateFunctionParameters(inputs)))
            """)
        }
    } else {
        text.append("""
        Void
        """)
    }
    
    text.append("""
    > {
    
    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        text.append("""
        let inputs: [SolidityEvent.Parameter] = [
        """)
        text.append(generateParameterArray(inputs))
        text.append("""
        ]
        
        """)
    } else {
        text.append("""
        let inputs: [SolidityEvent.Parameter] = []
        
        """)
    }
    
    text.append("""
    let event = SolidityEvent(name: "\(item.name!)", anonymous: \(item.anonymous!), inputs: inputs)

    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        if inputs.count == 1 && inputs[0].components == nil  {
            text.append("""
            return SolidityTypedEvent(event: event, { \(dictResult) in
                return \(generateMappingSingle(inputs[0]))
            })
            }
            """)
        } else {
            text.append("""
            return SolidityTypedEvent(event: event, { \(dictResult) in
                return (\(generateMapping(inputs)))
            })
            }
            """)
        }
    } else {
        text.append("""
        return SolidityTypedEvent(event: event, { _ in
            return
        })
        }
        """)
    }
    
    return text.joined()
}

/// Generate function inputs parameter recursively
/// Not all types are supported
/// Example:
/// from: EthereumAddress, to: EthereumAddress, value: BigUInt
private func generateFunctionParameters(_ parameters: [Parameter], unnamedParamCount: Int = 0) -> String {
    var newParamCount = unnamedParamCount
    var text = ""
    for (index, parameter) in parameters.enumerated() {
        if index != 0 {
            text += ", "
        }
        var name = parameter.name
        if parameter.name.isEmpty {
            name = "\(unnamed)\(newParamCount)"
            newParamCount += 1
        }
        
        //is tuple
        if let components = parameter.components {
            text += "\(name): (\(generateFunctionParameters(components, unnamedParamCount: newParamCount)))"
        } else {
            text += "\(name): \(toLocalType(parameter.type))"
        }
    }
    return text
}

/// Generate function inputs name recursively
/// Example:
/// from, to, value
private func generateFunctionParametersName(_ parameters: [Parameter], unnamedParamCount: Int = 0) -> String {
    var newParamCount = unnamedParamCount
    var text = ""
    for (index, parameter) in parameters.enumerated() {
        if index != 0 {
            text += ", "
        }
        
        var name = parameter.name
        if parameter.name.isEmpty {
            name = "\(unnamed)\(newParamCount)"
            newParamCount += 1
        }
        
        //is tuple
        if let components = parameter.components {
            text += "(\(generateFunctionParametersName(components, unnamedParamCount: newParamCount)))"
        } else {
            text += "\(name)"
        }
    }
    return text
}

/// Generate mapping from dictionary of any to static type for single parameter
/// Example:
/// result["param0"] as! String
private func generateMappingSingle(_ parameter: Parameter) -> String {
    let name = parameter.name == "" ? "\(unnamed)0" : parameter.name
    return """
    \(dictResult)[\"\(name)\"] as! \(toLocalType(parameter.type))
    """
}

/// Generate mapping from dictionary of any to static type for list of parameter
/// Example:
/// result["param0"] as! String, result["name"] as! Int
private func generateMapping(_ parameters: [Parameter], unnamedParamCount: Int = 0) -> String {
    var newParamCount = unnamedParamCount
    var text = ""
    for (index, parameter) in parameters.enumerated() {
        if index != 0 {
            text += ", "
        }
        var name = parameter.name
        if parameter.name.isEmpty {
            name = "\(unnamed)\(newParamCount)"
            newParamCount += 1
        }
        
        //is tuple
        if let components = parameter.components {
            text += "(\(generateMapping(components, unnamedParamCount: newParamCount)))"
        } else {
            text += "\(dictResult)[\"\(name)\"] as! \(toLocalType(parameter.type))"
        }
    }
    return text
}

/// Generate function
private func generateFunction(_ item: ContractItem) -> String {
    var text: [String] = []
    let hasInput: Bool = !(item.inputs?.isEmpty ?? true)
    let hasOutput: Bool = !(item.outputs?.isEmpty ?? true)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        text.append("""
        func \(item.name!)(\(generateFunctionParameters(inputs))) -> SolidityTypedInvocation<
        """)
    } else {
        text.append("""
        func \(item.name!)() -> SolidityTypedInvocation<
        """)
    }
    
    if let outputs = item.outputs, !outputs.isEmpty {
        if outputs.count == 1 && outputs[0].components == nil {
            text.append("""
            \(toLocalType(outputs[0].type))
            """)
        } else {
            text.append("""
            (\(generateFunctionParameters(outputs)))
            """)
        }
    } else {
        text.append("""
        Void
        """)
    }
    
    text.append("""
    > {
    
    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        text.append("""
        let inputs: [SolidityFunctionParameter] = [
        \(generateParameterArray(inputs))
        ]
        
        """)
    }
    
    if let outputs = item.outputs, !outputs.isEmpty {
        text.append("""
        let outputs: [SolidityFunctionParameter] = [
        \(generateParameterArray(outputs))
        ]
        
        """)
    }
    
    switch item.stateMutability! {
    case .view, .pure:
        text.append("let method = SolidityConstantFunction(")
    case .nonpayable:
        text.append("let method = SolidityNonPayableFunction(")
    case .payable:
        text.append("let method = SolidityPayableFunction(")
    }
    
    text.append("""
    name: "\(item.name!)"\(hasInput ? ", inputs: inputs":"")\(hasOutput ? ", outputs: outputs":""), handler: self)
    
    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        text.append("""
        let invocation = method.invoke(\(generateFunctionParametersName(inputs)))
        
        """)
    } else {
        text.append("""
        let invocation = method.invoke()
        
        """)
    }
    
    if let outputs = item.outputs, !outputs.isEmpty {
        if outputs.count == 1 && outputs[0].components == nil {
            text.append("""
            return SolidityTypedInvocation(invocation: invocation, { \(dictResult) in
                return \(generateMappingSingle(outputs[0]))
            })
            }
            """)
        } else {
            text.append("""
            return SolidityTypedInvocation(invocation: invocation, { \(dictResult) in
                return (\(generateMapping(outputs)))
            })
            }
            """)
        }
        
    } else {
        text.append("""
        return SolidityTypedInvocation(invocation: invocation, { _ in
            return
        })
        }
        """)
    }
    return text.joined()
}

/// Generate constructor deploy function
private func generateConstructor(_ item: ContractItem, bytecode: String) -> String {
    var text: [String] = []
    
    text.append("""
    func deploy(
    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        text.append("""
        \(generateFunctionParameters(inputs))
        """)
    }
    
    text.append("""
    ) -> SolidityConstructorInvocation {
    
    let byteCode = try! EthereumData(ethereumValue: "\(bytecode)")
    
    let constructor = SolidityConstructor(
    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        text.append("""
        inputs: [\(generateParameterArray(inputs))]
        """)
    } else {
        text.append("""
        ) ->
        inputs: []
        """)
    }
    
    if let payable = item.payable {
        text.append("""
        , payable: \(payable)
        """)
    }
    
    text.append("""
    , handler: self)
    return constructor.invoke(byteCode: byteCode, parameters: [
    """)
    
    if let inputs = item.inputs, !inputs.isEmpty {
        text.append("""
        \(generateFunctionParametersName(inputs))
        """)
    }
    
    text.append("""
    ])
    }
    """)
    
    return text.joined()
}

private func generateEventProperty(_ items: [ContractItem], classname: String) -> String {
    var text: [String] = []
    text.append("""
    var events: [SolidityEvent] {
        return [
    """)
    
    for (index, item) in items.enumerated() {
        guard case .event = item.type else {
            fatalError("Provided contract item must be event type")
        }
        if index != 0 {
            text.append(", ")
        }
        
        text.append("\(classname).\(item.name!).event")
    }
    
    text.append("""
    ]
    }
    
    """)
    return text.joined()
}

struct Codegen {
    static func generate(
            contractName: String,
            _ contractJson: ContractJson,
            importList: [String] = ["Web3"]
    ) -> String {
        let source = contractJson.abi
        var text = """
        // Generated File
        
        import Foundation
        import BigInt
        
        """
        
        importList.forEach { item in
            text += """
            import \(item)
            
            """
        }
        
        text += """
        
        public class \(contractName): StaticContract {
            public var address: EthereumAddress?
            public var eth: Web3.Eth
        
            required public init(address: EthereumAddress?, eth: Web3.Eth) {
                self.address = address
                self.eth = eth
            }
        
        """
        
        let eventContractItems: [ContractItem] = source
            .filter({ item in
                switch item.type {
                case .event:
                    return true
                default:
                    return false
                }
            })
        
        if !eventContractItems.isEmpty {
            text += "public " + generateEventProperty(eventContractItems, classname: contractName)
        }
        
        source.forEach { item in
            switch item.type {
            case .constructor:
                text.append("""
                 public \(generateConstructor(item, bytecode: contractJson.bytecode))
                 
                 """)
            case .event:
                text.append("""
                 public \(generateEvent(item))
                 
                 """)
            case .function:
                text.append("""
                 public \(generateFunction(item))
                 
                 """)
            default:
                print("Not handling \(item.type)")
            }
        }
        
        text.append("""
        }
        """)
        
        return text
    }

}
