//
//  YYJsonEncoderTests.swift
//  YYJsonEncoder
//
//  Created by Santiago Alvarez on 30/10/2025.
//

import XCTest
import YYJsonEncoder
import Foundation

enum EventType: String {
    case exec
    case fork
}

// Conform to YYJsonEncodable for easy encoding
extension EventType: YYJsonEncodable {
    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createString(rawValue)
    }
}

struct Certificate: YYJsonEncodable {
    let name: String

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "name", value: name)
        return obj
    }
}

struct File: YYJsonEncodable {
    let path: String
    let name: String
    let metadata: String?
    let owners: [Int64]
    let certs: [Certificate]

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "path", value: path)
        encoder.add(to: obj, key: "name", value: name)
        encoder.add(to: obj, key: "metadata", value: metadata)  // handles Optional automatically
        encoder.add(to: obj, key: "owners", value: encoder.createArray(owners))
        encoder.add(to: obj, key: "certs", value: encoder.createArray(certs))
        return obj
    }
}

class Proc: YYJsonEncodable {
    let file: File
    let pid: Int64
    let ppid: Int64

    init(file: File, pid: Int64, ppid: Int64) {
        self.file = file
        self.pid = pid
        self.ppid = ppid
    }

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "file", value: file)
        encoder.add(to: obj, key: "pid", value: pid)
        encoder.add(to: obj, key: "ppid", value: ppid)
        return obj
    }
}

struct Event: YYJsonEncodable {
    let date: Date
    let eventType: EventType
    let process: Proc

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "date", value: date)
        encoder.add(to: obj, key: "eventType", value: eventType)
        encoder.add(to: obj, key: "process", value: process)
        return obj
    }
}

final class YYJsonEncoderTests: XCTestCase {

    func testBasicEncoding() throws {
        let encoder = YYJsonEncoder()

        let event = Event(
            date: Date(),
            eventType: .exec,
            process: Proc(
                file: File(
                    path: "/bin/ls",
                    name: "ls",
                    metadata: nil,
                    owners: [0],
                    certs: []
                ),
                pid: 1,
                ppid: 0
            )
        )

        let json = try encoder.encode(event.encode(to: encoder))

        // Verify the JSON contains expected keys
        XCTAssertTrue(json.contains("\"date\""))
        XCTAssertTrue(json.contains("\"eventType\""))
        XCTAssertTrue(json.contains("\"process\""))
        XCTAssertTrue(json.contains("\"pid\""))
        print("Basic encoding result:", json)
    }

    func testSnakeCaseEncoding() throws {
        let encoder = YYJsonEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let event = Event(
            date: Date(timeIntervalSince1970: 1234567890),
            eventType: .exec,
            process: Proc(
                file: File(
                    path: "/bin/ls",
                    name: "ls",
                    metadata: "test",
                    owners: [0, 1, 2],
                    certs: [Certificate(name: "cert1")]
                ),
                pid: 1,
                ppid: 0
            )
        )

        let json = try encoder.encode(event.encode(to: encoder))

        // Verify snake_case conversion
        XCTAssertTrue(json.contains("\"event_type\""))
        XCTAssertFalse(json.contains("\"eventType\""))
        print("Snake case encoding result:", json)
    }

    func testPrettyPrinting() throws {
        let encoder = YYJsonEncoder()
        encoder.outputFormatting = .prettyPrinted

        let obj = encoder.createObject()
        encoder.add(to: obj, key: "name", value: "test")
        encoder.add(to: obj, key: "value", value: 42)

        let json = try encoder.encode(obj)

        // Pretty printed JSON should contain newlines and indentation
        XCTAssertTrue(json.contains("\n"))
        XCTAssertTrue(json.contains("    ")) // 4 space indent
        print("Pretty printed result:\n", json)
    }

    func testPrettyPrintingTwoSpaces() throws {
        let encoder = YYJsonEncoder()
        encoder.outputFormatting = .prettyPrintedTwoSpaces

        let obj = encoder.createObject()
        encoder.add(to: obj, key: "name", value: "test")

        let json = try encoder.encode(obj)

        // Pretty printed JSON should contain newlines
        XCTAssertTrue(json.contains("\n"))
        print("Pretty printed (2 spaces) result:\n", json)
    }

    func testGenericArrayCreation() throws {
        let encoder = YYJsonEncoder()

        // Test with various types
        let intArray = encoder.createArray([1, 2, 3, 4, 5])
        let stringArray = encoder.createArray(["a", "b", "c"])
        let doubleArray = encoder.createArray([1.1, 2.2, 3.3])

        let obj = encoder.createObject()
        encoder.add(to: obj, key: "ints", value: intArray)
        encoder.add(to: obj, key: "strings", value: stringArray)
        encoder.add(to: obj, key: "doubles", value: doubleArray)

        let json = try encoder.encode(obj)

        XCTAssertTrue(json.contains("[1,2,3,4,5]"))
        XCTAssertTrue(json.contains("[\"a\",\"b\",\"c\"]"))
        print("Generic array result:", json)
    }

    func testOptionalHandling() throws {
        let encoder = YYJsonEncoder()

        let obj = encoder.createObject()

        let presentValue: String? = "present"
        let nilValue: String? = nil

        // add() with optional omits nil values
        encoder.add(to: obj, key: "present", value: presentValue)
        encoder.add(to: obj, key: "absent", value: nilValue)

        let json = try encoder.encode(obj)

        XCTAssertTrue(json.contains("\"present\""))
        XCTAssertFalse(json.contains("\"absent\""))
        print("Optional handling result:", json)
    }

    func testAddOrNull() throws {
        let encoder = YYJsonEncoder()

        let obj = encoder.createObject()

        let presentValue: String? = "present"
        let nilValue: String? = nil

        // addOrNull() encodes nil as JSON null
        encoder.addOrNull(to: obj, key: "present", value: presentValue)
        encoder.addOrNull(to: obj, key: "nullValue", value: nilValue)

        let json = try encoder.encode(obj)

        XCTAssertTrue(json.contains("\"present\":\"present\""))
        XCTAssertTrue(json.contains("\"nullValue\":null"))
        print("AddOrNull result:", json)
    }

    func testAllIntegerTypes() throws {
        let encoder = YYJsonEncoder()

        let obj = encoder.createObject()
        encoder.add(to: obj, key: "int", value: Int(42))
        encoder.add(to: obj, key: "int8", value: Int8(8))
        encoder.add(to: obj, key: "int16", value: Int16(16))
        encoder.add(to: obj, key: "int32", value: Int32(32))
        encoder.add(to: obj, key: "int64", value: Int64(64))
        encoder.add(to: obj, key: "uint", value: UInt(42))
        encoder.add(to: obj, key: "uint8", value: UInt8(8))
        encoder.add(to: obj, key: "uint16", value: UInt16(16))
        encoder.add(to: obj, key: "uint32", value: UInt32(32))
        encoder.add(to: obj, key: "uint64", value: UInt64(64))

        let json = try encoder.encode(obj)

        XCTAssertTrue(json.contains("\"int\":42"))
        XCTAssertTrue(json.contains("\"int64\":64"))
        XCTAssertTrue(json.contains("\"uint64\":64"))
        print("All integer types result:", json)
    }

    func testFloatAndDouble() throws {
        let encoder = YYJsonEncoder()

        let obj = encoder.createObject()
        encoder.add(to: obj, key: "float", value: Float(3.14))
        encoder.add(to: obj, key: "double", value: Double(2.718281828))

        let json = try encoder.encode(obj)

        XCTAssertTrue(json.contains("\"float\":"))
        XCTAssertTrue(json.contains("\"double\":"))
        print("Float and double result:", json)
    }
}
