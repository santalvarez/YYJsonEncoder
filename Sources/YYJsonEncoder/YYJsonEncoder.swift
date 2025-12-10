import Foundation
import CYYJsonEncoder

/// Key encoding strategy for JSON object keys
public enum KeyEncodingStrategy {
    case useDefaultKeys
    case convertToSnakeCase
    case custom((String) -> String)
}

/// Output formatting options
public struct OutputFormatting: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Write JSON with 4 space indent (maps to YYJSON_WRITE_PRETTY)
    public static let prettyPrinted = OutputFormatting(rawValue: YYJSON_WRITE_PRETTY)
    /// Write JSON with 2 space indent (maps to YYJSON_WRITE_PRETTY_TWO_SPACES)
    public static let prettyPrintedTwoSpaces = OutputFormatting(rawValue: YYJSON_WRITE_PRETTY_TWO_SPACES)
    /// Escape unicode as \uXXXX, making output ASCII only (maps to YYJSON_WRITE_ESCAPE_UNICODE)
    public static let escapeUnicode = OutputFormatting(rawValue: YYJSON_WRITE_ESCAPE_UNICODE)
    /// Escape '/' as '\/' (maps to YYJSON_WRITE_ESCAPE_SLASHES)
    public static let escapeSlashes = OutputFormatting(rawValue: YYJSON_WRITE_ESCAPE_SLASHES)
    /// Add a newline character at the end of the JSON (maps to YYJSON_WRITE_NEWLINE_AT_END)
    public static let newlineAtEnd = OutputFormatting(rawValue: YYJSON_WRITE_NEWLINE_AT_END)
}

/// Date encoding strategy
public enum DateEncodingStrategy {
    case secondsSince1970
    case millisecondsSince1970
    case iso8601
    case custom((Date) -> String)
}

/// Protocol for types that can be encoded to JSON using YYJsonEncoder
public protocol YYJsonEncodable {
    func encode(to encoder: YYJsonEncoder) -> ValueRef
}

/// A reference to a yyjson mutable value
public class ValueRef {
    fileprivate let pointer: UnsafeMutablePointer<yyjson_mut_val>
    fileprivate weak var encoder: YYJsonEncoder?

    fileprivate init(pointer: UnsafeMutablePointer<yyjson_mut_val>, encoder: YYJsonEncoder) {
        self.pointer = pointer
        self.encoder = encoder
    }
}

/// High-performance JSON encoder using yyjson
public class YYJsonEncoder {
    private var doc: UnsafeMutablePointer<yyjson_mut_doc>?

    /// Key encoding strategy for object keys
    public var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys

    /// Date encoding strategy
    public var dateEncodingStrategy: DateEncodingStrategy = .secondsSince1970

    /// Output formatting options
    public var outputFormatting: OutputFormatting = []

    public init() {
        self.doc = yyjson_mut_doc_new(nil)
    }

    deinit {
        if let doc = doc {
            yyjson_mut_doc_free(doc)
        }
    }

    /// Reset the encoder by freeing the current document and creating a new one
    /// This is called automatically after encode() and encodeData()
    private func reset() {
        if let doc = doc {
            yyjson_mut_doc_free(doc)
        }
        doc = yyjson_mut_doc_new(nil)
    }

    /// Transform a key according to the current encoding strategy
    func transformKey(_ key: String) -> String {
        switch keyEncodingStrategy {
        case .useDefaultKeys:
            return key
        case .convertToSnakeCase:
            return convertToSnakeCase(key)
        case .custom(let transform):
            return transform(key)
        }
    }

    /// Convert camelCase to snake_case
    private func convertToSnakeCase(_ input: String) -> String {
        var result = ""
        for (index, character) in input.enumerated() {
            if character.isUppercase {
                if index > 0 {
                    result.append("_")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Ensures the document is valid
    private func ensureDocument() -> UnsafeMutablePointer<yyjson_mut_doc> {
        if let doc = doc {
            return doc
        }
        let newDoc = yyjson_mut_doc_new(nil)!
        doc = newDoc
        return newDoc
    }

    // MARK: - Value Creation

    /// Create a new JSON object
    public func createObject() -> ValueRef {
        let doc = ensureDocument()
        let val = yyjson_mut_obj(doc)!
        return ValueRef(pointer: val, encoder: self)
    }

    /// Create a new JSON array
    public func createArray() -> ValueRef {
        let doc = ensureDocument()
        let val = yyjson_mut_arr(doc)!
        return ValueRef(pointer: val, encoder: self)
    }

    // MARK: - Internal Value Creation

    func createString(_ value: String) -> ValueRef {
        let doc = ensureDocument()
        let val = value.withCString { cStr in
            yyjson_mut_strncpy(doc, cStr, value.utf8.count)
        }!
        return ValueRef(pointer: val, encoder: self)
    }

    func createInt(_ value: Int64) -> ValueRef {
        let doc = ensureDocument()
        let val = yyjson_mut_sint(doc, value)!
        return ValueRef(pointer: val, encoder: self)
    }

    func createUInt(_ value: UInt64) -> ValueRef {
        let doc = ensureDocument()
        let val = yyjson_mut_uint(doc, value)!
        return ValueRef(pointer: val, encoder: self)
    }

    func createDouble(_ value: Double) -> ValueRef {
        let doc = ensureDocument()
        let val = yyjson_mut_real(doc, value)!
        return ValueRef(pointer: val, encoder: self)
    }

    func createBool(_ value: Bool) -> ValueRef {
        let doc = ensureDocument()
        let val = yyjson_mut_bool(doc, value)!
        return ValueRef(pointer: val, encoder: self)
    }

    func createNull() -> ValueRef {
        let doc = ensureDocument()
        let val = yyjson_mut_null(doc)!
        return ValueRef(pointer: val, encoder: self)
    }

    // MARK: - Internal Object/Array Manipulation

    private func addToObject(_ object: ValueRef, key: String, value: ValueRef) {
        let transformedKey = transformKey(key)
        let doc = ensureDocument()
        let keyVal = transformedKey.withCString { cStr in
            yyjson_mut_strncpy(doc, cStr, transformedKey.utf8.count)
        }!
        yyjson_mut_obj_add(object.pointer, keyVal, value.pointer)
    }

    func addToArray(_ array: ValueRef, value: ValueRef) {
        yyjson_mut_arr_append(array.pointer, value.pointer)
    }

    // MARK: - Internal JSON Writing

    private func write(_ value: ValueRef) throws -> String {
        var err = yyjson_write_err()
        var len: Int = 0
        let flags = yyjson_write_flag(outputFormatting.rawValue)

        guard let cString = yyjson_mut_val_write_opts(value.pointer, flags, nil, &len, &err) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: String(cString: err.msg)
            ))
        }

        defer { free(cString) }
        return String(cString: cString)
    }

    private func writeData(_ value: ValueRef) throws -> Data {
        let string = try write(value)
        return Data(string.utf8)
    }

    /// Encode a YYJsonEncodable value to a JSON String
    /// The encoder automatically resets after this call, ready for the next encoding operation
    public func encode<T: YYJsonEncodable>(_ value: T) throws -> String {
        let ref = value.encode(to: self)
        yyjson_mut_doc_set_root(ensureDocument(), ref.pointer)
        defer { reset() }
        return try write(ref)
    }

    /// Encode a YYJsonEncodable value to Data
    /// The encoder automatically resets after this call, ready for the next encoding operation
    public func encodeData<T: YYJsonEncodable>(_ value: T) throws -> Data {
        let ref = value.encode(to: self)
        yyjson_mut_doc_set_root(ensureDocument(), ref.pointer)
        defer { reset() }
        return try writeData(ref)
    }

    // MARK: - Generic Methods

    /// Add any YYJsonEncodable value to an object
    public func add<T: YYJsonEncodable>(to object: ValueRef, key: String, value: T) {
        addToObject(object, key: key, value: value.encode(to: self))
    }

    /// Add an optional YYJsonEncodable value to an object (omits key if nil)
    public func add<T: YYJsonEncodable>(to object: ValueRef, key: String, value: T?) {
        if let value = value {
            addToObject(object, key: key, value: value.encode(to: self))
        }
    }

    /// Add an optional YYJsonEncodable value to an object, encoding nil as JSON null
    public func addOrNull<T: YYJsonEncodable>(to object: ValueRef, key: String, value: T?) {
        if let value = value {
            addToObject(object, key: key, value: value.encode(to: self))
        } else {
            addToObject(object, key: key, value: createNull())
        }
    }

    /// Create an array from a Swift array of YYJsonEncodable values
    public func createArray<T: YYJsonEncodable>(_ values: [T]) -> ValueRef {
        let array = createArray()
        for value in values {
            addToArray(array, value: value.encode(to: self))
        }
        return array
    }

    // MARK: - Internal Date Handling

    func createDate(_ date: Date) -> ValueRef {
        switch dateEncodingStrategy {
        case .secondsSince1970:
            return createDouble(date.timeIntervalSince1970)
        case .millisecondsSince1970:
            return createDouble(date.timeIntervalSince1970 * 1000)
        case .iso8601:
            let formatter = ISO8601DateFormatter()
            return createString(formatter.string(from: date))
        case .custom(let transform):
            return createString(transform(date))
        }
    }
}

// MARK: - YYJsonEncodable Conformance for Primitive Types

extension String: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createString(self)
    }
}

extension Bool: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createBool(self)
    }
}

extension Int: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createInt(Int64(self))
    }
}

extension Int8: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createInt(Int64(self))
    }
}

extension Int16: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createInt(Int64(self))
    }
}

extension Int32: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createInt(Int64(self))
    }
}

extension Int64: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createInt(self)
    }
}

extension UInt: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createUInt(UInt64(self))
    }
}

extension UInt8: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createUInt(UInt64(self))
    }
}

extension UInt16: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createUInt(UInt64(self))
    }
}

extension UInt32: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createUInt(UInt64(self))
    }
}

extension UInt64: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createUInt(self)
    }
}

extension Double: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createDouble(self)
    }
}

extension Float: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createDouble(Double(self))
    }
}

extension Date: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        encoder.createDate(self)
    }
}

extension ValueRef: YYJsonEncodable {
    public func encode(to encoder: YYJsonEncoder) -> ValueRef {
        self
    }
}

