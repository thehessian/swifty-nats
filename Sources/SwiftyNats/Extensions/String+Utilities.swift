//
//  String+Utilities.swift
//  SwiftyNats
//
//  Created by Ray Krow on 2/27/18.
//

import Foundation

extension String {
    
    static func hash() -> String {
        let uuid = String.uuid()
        return uuid[0...7]
    }
    
    static func uuid() -> String {
        return UUID().uuidString.trimmingCharacters(in: .punctuationCharacters)
    }
    
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
    
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
    
    func removeNewlines() -> String {
        return self.components(separatedBy: CharacterSet.newlines).reduce("", {$0 + $1})
    }
    
    func removePrefix(_ prefix: String) -> String {
        let index = self.index(self.startIndex, offsetBy: prefix.count)
        return String(self[index...])
    }
    
    func toJsonDicitonary() -> [String: AnyObject]? {
        
        guard let data = self.data(using: String.Encoding.utf8) else { return nil }
        
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        
        return obj as? [String: AnyObject]
    }
    
    func getMessageType() -> NatsOperation? {
        
        guard self.count > 2 else { return nil }
        
        let isOperation: ((NatsOperation) -> Bool) = { no in
            let l = no.rawValue.count - 1
            guard self.count > l else { return false }
            let operation = String(self[0...l]).uppercased()
            guard operation == no.rawValue else { return false }
            return true
        }
        
        let firstCharacter = String(self[0...0]).uppercased()
        
        switch firstCharacter {
        case "C":
            guard isOperation(.connect) else { return nil }
            return .connect
        case "S":
            guard isOperation(.subscribe) else { return nil }
            return .subscribe
        case "U":
            guard isOperation(.unsubscribe) else { return nil }
            return .unsubscribe
        case "M":
            guard isOperation(.message) else { return nil }
            return .message
        case "I":
            guard isOperation(.info) else { return nil }
            return .info
        case "+":
            guard isOperation(.ok) else { return nil }
            return .ok
        case "-":
            guard isOperation(.error) else { return nil }
            return .error
        case "P":
            if isOperation(.ping) { return .ping }
            if isOperation(.pong) { return .pong }
            if isOperation(.publish) { return .publish }
            return nil
        default:
            return nil
        }
        
    }
    
    func parseOutMessages(prevBuffer: LastReadMessage?) -> ([String], LastReadMessage?) {
    
        var messages = [String]()
        let lines = self.components(separatedBy: "\n")

        var isMessageFlag = false
        var addedLastLine = false
        var lastLine = ""
        var existingMessage = prevBuffer
        var processedMsgFlag = false
        
        for parsedLine in lines {
            addedLastLine = false
            processedMsgFlag = false
            let line: String
            if let prefix = existingMessage {
                line = prefix.message + parsedLine
                isMessageFlag = prefix.processedMsgFlag
                existingMessage = nil
            } else {
                line = parsedLine
            }
        
            if isMessageFlag {
                addedLastLine = true
                messages.append(lastLine + line)
                isMessageFlag = false
                processedMsgFlag = true
                continue
            }
            
            lastLine = line
            let type = line.getMessageType()
            if type == nil { continue }
            
            switch (type!) {
            case .message:
                isMessageFlag = true
                break
            default:
                messages.append(line)
                addedLastLine = true
            }
        }

        var newExistingBuffer: LastReadMessage?
        if lastLine.count != 0 {
            // If the last line is not empty, then we didn't have a newline at the
            // end of our message which means that we are in the middle of processing
            // a message but we need to hear the rest of it.
            if addedLastLine {
                newExistingBuffer = LastReadMessage(message: messages.last!, processedMsgFlag: processedMsgFlag)
                messages.removeLast()
            } else {
                newExistingBuffer = LastReadMessage(message: lastLine, processedMsgFlag: processedMsgFlag)
            }
        }
        
        return (messages, newExistingBuffer)
    }
    
}
