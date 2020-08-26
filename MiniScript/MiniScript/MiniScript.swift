//
//  MiniScript.swift
//  MiniScript
//
//  Created by Matthew Reagan on 7/14/20.
//  Copyright © 2020 Matt Reagan. All rights reserved.
//

import Foundation

let MiniScriptErrorResult = "»» MiniScript Error! ««"
let MiniScriptPrintPrefixShorthand = "``"
fileprivate let strTokenMarker = "%_str_token_"
fileprivate let commandArgsMarker = "%_args_token_"
fileprivate let localVarPrefix = "$"
fileprivate let globalVarPrefix = "&"

final class MiniScriptEngine {
    fileprivate(set) var globalUserVariables: [String: Variable] = [:]
    fileprivate var commands: [String: CommandHandlerWrapper] = MiniScriptEngine.defaultCommands()
    
    fileprivate(set) var currentScript: MiniScript?
    
    // MARK: - API
    
    @discardableResult
    func run(_ script: MiniScript,
             environment: [String: String] = [:]) -> ScriptOutput {
        currentScript = script
        script.engine = self
        for (envVar, envVal) in environment {
            script.userVariables[envVar] = Variable(string: envVal)
        }
        let output = script.execute()
        currentScript = nil
        return output
    }
}

extension MiniScriptEngine {
    func addCommand(_ command: String, block: @escaping CommandHandler) {
        commands[command.trimmed().lowercased()] = CommandHandlerWrapper(handler: block)
    }
    
    fileprivate static func defaultCommands() -> [String: CommandHandlerWrapper] {
        var commands: [String: CommandHandlerWrapper] = [:]
        
        for command in MiniScriptDefaultCommand.allCases.map({ $0.rawValue }) {
            commands[command] = CommandHandlerWrapper(handler: nil)
        }
        return commands
    }
}

typealias CommandHandler = (([String]) -> String?)
final class CommandHandlerWrapper {
    let handler: CommandHandler?
    init(handler: CommandHandler?) {
        self.handler = handler
    }
}

final class MiniScript {
    
    let source: String
    
    // MARK: - User Variables
    
    fileprivate(set) var userVariables: [String: Variable] = [:]
    fileprivate weak var engine: MiniScriptEngine?
    
    // MARK: - Internal Storage
    
    private var statements: [Statement] = []
    private var sourceStrings: [String] = []
    private var sourceArguments: [String] = []
    private var scriptOutput = ""
        
    // MARK: - Public API
    
    init(source: String) {
        self.source = source
    }
    
    @discardableResult
    fileprivate func execute() -> ScriptOutput {
        prepareScript(source)
        
        scriptOutput = ""
        let s = statements
        var linePointer = 0
        var depth = 0
        var loopStart: [Int: Int] = [:] // Depth -> Line #
        
        while linePointer < s.count {
            let s = statements[linePointer]
            let t = s.tokens
            
            switch t[0].type {
            case .if, .while:
                if t[0].type == .while {
                        depth += 1
                    guard let evaluated = evaluateExpression(t, startingAt: 1) else {
                        return MiniScriptErrorResult
                    }
                    let evaluatedAsTrue = (evaluated.numericValue != 0.0) || evaluated.string.lowercased() == "true"
                    
                    if evaluatedAsTrue {
                        loopStart[depth] = linePointer
                        linePointer += 1
                    } else {
                        if let nextEnd = nextEndStatement(depth: depth, startingFrom: linePointer) {
                            linePointer = nextEnd
                        } else {
                            return MiniScriptErrorResult
                        }
                    }
                } else {
                    depth += 1
                    
                    guard let evaluated = evaluateExpression(t, startingAt: 1) else {
                        return MiniScriptErrorResult
                    }
                    let evaluatedAsTrue = (evaluated.numericValue != 0.0) || evaluated.string.lowercased() == "true"
                    
                    if evaluatedAsTrue {
                        linePointer += 1
                    } else {
                        if let elseLine = nextElseStatement(depth: depth, startingFrom: linePointer) {
                            linePointer = elseLine + 1
                        } else {
                            if let nextEnd = nextEndStatement(depth: depth, startingFrom: linePointer) {
                                linePointer = nextEnd
                            } else {
                                return MiniScriptErrorResult
                            }
                        }
                    }
                }
            case .else:
                if let nextEnd = nextEndStatement(depth: t[0].depth, startingFrom: linePointer) {
                    linePointer = nextEnd
                } else {
                    return MiniScriptErrorResult
                }
            case .command:
                evaluateStatement(t[0])
                linePointer += 1
            case .statement:
                linePointer += 1
            case .end:
                if let start = loopStart[depth] {
                    loopStart.removeValue(forKey: depth)
                    depth -= 1
                    linePointer = start
                } else {
                    depth -= 1
                    linePointer += 1
                }
            case .variable:
                guard t.count >= 3 else { return MiniScriptErrorResult }
                guard t[1].type == .operator else { return MiniScriptErrorResult }
                if t[1].operator! == .equals {
                    let variableID = String(t[0].raw.dropFirst(1))
                    
                    let isLocal = t[0].raw.hasLocalVarPrefix
                    if t.count >= 5 {
                        // Start at 3rd arg (index 2), perform all operations to right of '='
                        let argIdx = 2
                        if isLocal {
                            userVariables[variableID] = evaluateExpression(t, startingAt: argIdx)
                        } else {
                            engine?.globalUserVariables[variableID] = evaluateExpression(t, startingAt: argIdx)
                        }
                    } else {
                        // Simple assign
                        if isLocal {
                            userVariables[variableID] = Variable(string: evaluateStatement(t[2]))
                        } else {
                            engine?.globalUserVariables[variableID] = Variable(string: evaluateStatement(t[2]))
                        }
                    }
                    
                    linePointer += 1
                }
            case .operator:
                return MiniScriptErrorResult
            }
        }
        
        return scriptOutput
    }
    
    private func evaluateExpression(_ t: [Token], startingAt: Int) -> Variable? {
        
        if startingAt == t.count - 1 {
            // Singular expression
            return Variable(string:evaluateStatement(t[startingAt]))
        } else {
            
            // This is simplistic and doesn't allow for operation precedence
            // or proper math order of operations for now
            var argIdx = startingAt
            guard argIdx < t.count else { return nil }
            var result = Variable(string: evaluateStatement(t[argIdx]))
            argIdx += 1
            while argIdx < t.count - 1 {
                let left = result
                let oper = t[argIdx]
                let right = t[argIdx + 1]
                
                result = left.operateOn(oper.operator!, other: Variable(string: evaluateStatement(right)))
                
                argIdx += 2
            }
            return result
        }
    }
    
    private func prepareScript(_ source: String) {
        self.sourceStrings.removeAll()
        self.sourceArguments.removeAll()
        
        // Trim lines, filter out empty or // commented lines
        let lines = source.trimmed().components(separatedBy: "\n").map({ $0.trimmed() }).filter({ !$0.isEmpty }).filter({ !$0.hasPrefix("//") })
        
        // Perform shorthand print checks first. Any lines beginning with `` are
        // changed into print statements. This is a convenience to allow long
        // strings to be easily output without requiring 'print("…")`.
        var shorthandProcessed: [String] = []
        for line in lines {
            if line.hasPrefix(MiniScriptPrintPrefixShorthand) {
                let content = line.dropFirst(MiniScriptPrintPrefixShorthand.count)
                shorthandProcessed.append("print(\"" + content + "\")")
            } else {
                shorthandProcessed.append(line)
            }
        }
        
        // Perform a pre-pass on each line. We check for " and when we see
        // one we continue scanning until the ending ". We then store this
        // string in a look-up and replace it with an identifier so the string
        // can be used later in the scripts
        
        var stringProcessedLines: [String] = []
        for line in shorthandProcessed {
            stringProcessedLines.append(processLineToExtractStringsWithQuotes(line))
        }
        
        // Similar pass is done for command arguments, we look
        // specifically for ( and ) and extract those to reference later
        
        var commandProcessedLines: [String] = []
        for line in stringProcessedLines {
            commandProcessedLines.append(processLineToSubstituteCommandArgumentsMarker(line))
        }
        
        self.statements = commandProcessedLines.map({ Statement(line: $0, engine: engine!) })
        
        // Hydrate with control flow metadata
        var depth = 0
        for s in statements {
            let first = s.tokens.first!
            if first.type == .if || first.type == .while {
                depth += 1
                first.depth = depth
            } else if first.type == .else {
                first.depth = depth
            } else if first.type == .end {
                first.depth = depth
                depth -= 1
            }
        }
    }
    
    // MARK: - Internal
    
    private func processLineToExtractStringsWithQuotes(_ line: String) -> String {
        var stringsFoundInLine: [String] = []
        var start: Int? = nil
        
        for (idx, c) in line.enumerated() {
            let prev: Character? = (idx > 0 ? line[line.index(line.startIndex, offsetBy: idx - 1)] : nil)
            if c == "\"" && prev != "\\" {
                if start == nil {
                    start = idx
                } else {
                    // We hit the ending ", pull out the string
                    let startIdx = line.index(line.startIndex, offsetBy: start!)
                    let endIdx = line.index(line.startIndex, offsetBy: idx)
                    let str = line[startIdx...endIdx]
                    stringsFoundInLine.append(String(str))
                }
            }
        }
        
        if stringsFoundInLine.isEmpty {
            return line
        } else {
            var newLine = line
            // Replace all of the strings with token identifiers and store the strings
            for str in stringsFoundInLine {
                guard let range = newLine.range(of: str) else { return line }
                sourceStrings.append(String(str.dropFirst(1).dropLast(1)))
                newLine = newLine.replacingCharacters(in: range, with: "\(strTokenMarker)\(sourceStrings.count - 1)")
            }
            return newLine
        }
    }
    
    private func processLineToSubstituteCommandArgumentsMarker(_ line: String) -> String {
        var argsFoundInLine: [String] = []
        var start: Int? = nil
        
        for (idx, c) in line.enumerated() {
            if c == "(" {
                if start == nil {
                    start = idx
                }
            } else if c == ")" {
                // We hit the ending ), pull out the arguments
                let startIdx = line.index(line.startIndex, offsetBy: start!)
                let endIdx = line.index(line.startIndex, offsetBy: idx)
                let args = line[startIdx...endIdx]
                argsFoundInLine.append(String(args))
            }
        }
        
        if argsFoundInLine.isEmpty {
            return line
        } else {
            var newLine = line
            // Replace all of the arguments with identifiers and store
            for arg in argsFoundInLine {
                let range = newLine.range(of: arg)!
                sourceArguments.append(String(arg.dropFirst(1).dropLast(1)))
                newLine = newLine.replacingCharacters(in: range, with: "\(commandArgsMarker)\(sourceArguments.count - 1)")
            }
            return newLine
        }
    }
    
    func nextElseStatement(depth: Int, startingFrom: Int) -> Int? {
        for i in startingFrom..<statements.count {
            let s = statements[i]
            let t = s.tokens.first!
            if t.type == .else && t.depth == depth {
                return i
            } else if t.type == .end && t.depth == depth {
                return nil
            }
            if t.type == .else && t.depth < depth {
                return nil
            }
        }
        return nil
    }
    
    func nextEndStatement(depth: Int, startingFrom: Int) -> Int? {
        for i in startingFrom..<statements.count {
            let s = statements[i]
            let t = s.tokens.first!
            if t.type == .end && t.depth == depth {
                return i
            }
        }
        return nil
    }
    
    func evaluateStringInterpolation(_ str: String) -> String {
        var result = str
        var interpolations: [String] = []
        var start: Int? = nil
        for (idx, c) in str.enumerated() {
            guard idx + 1 < str.count else { continue }
            if start == nil && c == "{" && str[str.index(str.startIndex, offsetBy: idx + 1)] == "{" {
                start = idx
            } else if start != nil && c == "}" && str[str.index(str.startIndex, offsetBy: idx + 1)] == "}" {
                // We hit the ending }
                let startIdx = str.index(str.startIndex, offsetBy: start!)
                let endIdx = str.index(str.startIndex, offsetBy: idx + 1)
                let interpolationRaw = str[startIdx...endIdx]
                interpolations.append(String(interpolationRaw))
                start = nil
            }
        }
        
        if interpolations.isEmpty {
        } else {
            for raw in interpolations {
                let range = result.range(of: raw)!
                let statementToEvaluate = String(raw.dropFirst(2).dropLast(2))
                
                // Pre-process the raw substitution to ensure that if it's a command, we
                // parse out the arguments
                let processed = processLineToSubstituteCommandArgumentsMarker(statementToEvaluate)
                
                guard let output = evaluateExpression(Statement(line: processed, engine: engine!).tokens, startingAt: 0)?.string else {
                    return ""
                }
                result = result.replacingCharacters(in: range, with: output)
            }
        }
        
        result = result.replacingOccurrences(of: "\\{\\{", with: "{{")
        result = result.replacingOccurrences(of: "\\}\\}", with: "}}")
        
        return result
    }
    
    @discardableResult
    func evaluateStatement(_ token: Token) -> String {
        
        func sourceString(from marker: String) -> String {
            if let strID = Int(marker.dropFirst(strTokenMarker.count)) {
                let rawStr = sourceStrings[strID]
                let fixEscapes = rawStr.replacingOccurrences(of: "\\\"", with: "\"")
                return evaluateStringInterpolation(fixEscapes)
            }
            return marker
        }
        
        func userVariable(from marker: String) -> String {
            let variableIdentifier = String(marker.dropFirst())
            return userVariables[variableIdentifier]?.string ?? ""
        }
        
        func globalUserVariable(from marker: String) -> String {
            let variableIdentifier = String(marker.dropFirst())
            return engine?.globalUserVariables[variableIdentifier]?.string ?? ""
        }
        
        func evaluateRaw(_ raw: String) -> String? {
            if raw.hasLocalVarPrefix {
                return userVariable(from: raw)
            } else if raw.hasGlobalVarPrefix {
                return globalUserVariable(from: raw)
            } else if raw.hasPrefix(strTokenMarker) {
                return sourceString(from: raw)
            }
            return nil
        }
        
        if let evaluatedRawToken = evaluateRaw(token.raw) {
            return evaluatedRawToken
        } else if token.type == .command {
            // Separate the command and the argument marker
            let commandParts = token.raw.components(separatedBy: "%")
            let command = token.command!
            let argIndexStr = commandParts[1].dropFirst(commandArgsMarker.count - 1)
            let argIndex = Int(String(argIndexStr))!
            var arguments = sourceArguments[argIndex].components(separatedBy: ",").map({ $0.trimmed() })
            
            arguments = arguments.map({ evaluateRaw($0) ?? $0 })
            
            return executeCommand(command, arguments: arguments) ?? ""
        }
        return token.rawOriginalCase
    }
    
    func executeCommand(_ command: String, arguments: [String]) -> String? {
        guard let engine = engine else { fatalError() }

        if let handler = engine.commands[command]?.handler {
            return handler(arguments) ?? ""
        } else {
            guard let c = MiniScriptDefaultCommand(rawValue: command) else { fatalError() }
            // Handle built-in command
            switch c {
            case .print, .printc:
                let printOutput = arguments.joined()
                performPrint(printOutput, onNewLine: c == .print)
                return printOutput
            case .rand:
                guard let max = Int(arguments[0]) else { return nil }
                return "\(Int.random(in: 0..<max))"
            }
        }
    }
    
    func performPrint(_ str: String, onNewLine: Bool) {
        if onNewLine {
            if !scriptOutput.isEmpty {
                scriptOutput += "\n"
            }
        }
        if !str.isEmpty {
            scriptOutput += str
        }
    }
}

fileprivate enum MiniScriptDefaultCommand: String, CaseIterable {
    case print
    case printc
    case rand
}

class Statement {
    
    private(set) var tokens: [Token]
    
    init(line: String, engine: MiniScriptEngine) {
        let spacedComps = line.components(separatedBy: " ")
        let first = Token(spacedComps.first!, engine: engine)
        switch first.type {
        case .command:
            // Grab the contents within (…) and tokenize
            let insideParens = line.dropFirst(first.command!.count + 1).dropLast(1)
            let parenComps = String(insideParens).components(separatedBy: ",").map({ $0.trimmed() })
            self.tokens = [first] + parenComps.map({ Token($0, engine: engine) })
        default:
            self.tokens = spacedComps.map({ Token($0, engine: engine) })
        }
    }
}

enum TokenType {
    case command
    case `if`
    case `else`
    case end
    case statement
    case variable
    case `operator`
    case `while`
}

enum Operator: String, CaseIterable {
    case equals = "="
    case doesNotEqual = "!="
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case lessThan = "<"
    case greaterThan = ">"
    case lessThanOrEqual = "<="
    case greaterThanOrEqual = ">="
}

struct Variable {
    var string: String
    
    static let one = Variable(double: 1.0)
    static let zero = Variable(double: 0.0)
    
    init(double: Double) {
        if double.magnitude - Double(Int(double)).magnitude <= Double.leastNormalMagnitude {
            // Avoid unnecessary decimal ".0" etc.
            self.init(string: "\(Int(double))")
        } else {
            self.init(string: "\(double)")
        }
    }
        
    init(string: String) {
        self.string = string
    }
    
    var isNumeric: Bool {
        let charSet = CharacterSet(charactersIn: "1234567890.,-").inverted
        return (string as NSString).rangeOfCharacter(from: charSet).location == NSNotFound
    }
    var numericValue: Double {
        return Double(string) ?? 0.0
    }
    
    func operateOn(_ operator: Operator, other: Variable) -> Variable {
        switch `operator` {
        case .equals:
            if self.isNumeric && other.isNumeric {
                return self.numericValue == other.numericValue ? Variable.one : Variable.zero
            } else {
                return self.string == other.string ? Variable.one : Variable.zero
            }
        case .doesNotEqual:
            let equals = operateOn(.equals, other: other)
            return (equals.numericValue == 0.0) ? Variable.one : Variable.zero
        case .add:
            if self.isNumeric && other.isNumeric {
                return Variable(double: self.numericValue + other.numericValue)
            } else {
                return Variable(string: self.string + other.string)
            }
        case .subtract:
            if self.isNumeric && other.isNumeric {
                return Variable(double: self.numericValue - other.numericValue)
            }
        case .divide:
            if self.isNumeric && other.isNumeric {
                return Variable(double: self.numericValue / other.numericValue)
            }
        case .multiply:
            if self.isNumeric && other.isNumeric {
                return Variable(double: self.numericValue * other.numericValue)
            }
        case .lessThan:
            if self.isNumeric && other.isNumeric {
                return self.numericValue < other.numericValue ? Variable.one : Variable.zero
            }
        case .greaterThan:
            if self.isNumeric && other.isNumeric {
                return self.numericValue > other.numericValue ? Variable.one : Variable.zero
            }
        case .lessThanOrEqual:
            if self.isNumeric && other.isNumeric {
                return self.numericValue <= other.numericValue ? Variable.one : Variable.zero
            }
        case .greaterThanOrEqual:
            if self.isNumeric && other.isNumeric {
                return self.numericValue >= other.numericValue ? Variable.one : Variable.zero
            }
        }
        return Variable.zero
    }
}

class Token {
    let type: TokenType
    let raw: String
    let rawOriginalCase: String
    let command: String?
    let `operator`: Operator?
    
    // Metadata
    var depth: Int = 0
    
    init(_ string: String, engine: MiniScriptEngine) {
        self.rawOriginalCase = string
        let lower = string.lowercased()
        self.raw = lower
        var parsedCommand: String? = nil
        var parsedOperator: Operator? = nil
        self.type = {
            switch lower {
            case "if":
                return .if
            case "end":
                return .end
            case "else":
                return .else
            case "true", "false":
                return .statement
            case "while":
                return .while
            default:
                if lower.hasVarPrefix {
                    return .variable
                }
                
                for c in engine.commands.keys {
                    if lower.hasPrefix(c + commandArgsMarker) {
                        parsedCommand = c
                        return .command
                    }
                }
                
                for o in Operator.allCases {
                    if lower == o.rawValue {
                        parsedOperator = o
                        return .operator
                    }
                }
                
                return .statement
            }
        }()
        self.operator = parsedOperator
        self.command = parsedCommand
    }
}

typealias ScriptOutput = String

extension String {
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var hasLocalVarPrefix: Bool {
        return self.hasPrefix(localVarPrefix)
    }
    
    var hasGlobalVarPrefix: Bool {
        return self.hasPrefix(globalVarPrefix)
    }
    
    var hasVarPrefix: Bool {
        return hasLocalVarPrefix || hasGlobalVarPrefix
    }
}
