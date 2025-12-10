# YYJsonEncoder

A high-performance JSON encoder for Swift, powered by [yyjson](https://github.com/ibireme/yyjson) — one of the fastest JSON libraries available.

## Features

- **Blazing Fast**: Built on yyjson, which consistently outperforms other JSON libraries in benchmarks
- **Type-Safe**: Generic API with `YYJsonEncodable` protocol for custom types
- **Flexible Key Encoding**: Support for camelCase, snake_case, or custom key transformations
- **Multiple Date Strategies**: Unix timestamps, milliseconds, ISO8601, or custom formats
- **Output Formatting**: Pretty printing with configurable indentation
- **Memory Efficient**: Manual `reset()` for reusing encoder instances

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/YYJsonEncoder.git", from: "1.0.0")
]
```

Then add `YYJsonEncoder` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["YYJsonEncoder"]
)
```

## Quick Start

```swift
import YYJsonEncoder

struct User: YYJsonEncodable {
    let name: String
    let age: Int
    let active: Bool

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "name", value: name)
        encoder.add(to: obj, key: "age", value: age)
        encoder.add(to: obj, key: "active", value: active)
        return obj
    }
}

let encoder = YYJsonEncoder()
let user = User(name: "John", age: 30, active: true)

let json = try encoder.encode(user)
// {"name":"John","age":30,"active":true}
```

## Usage

### Basic Types

The encoder supports all Swift primitive types out of the box:

```swift
let encoder = YYJsonEncoder()
let obj = encoder.createObject()

// Strings
encoder.add(to: obj, key: "name", value: "Alice")

// Numbers (Int, Int8, Int16, Int32, Int64, UInt, UInt8, UInt16, UInt32, UInt64)
encoder.add(to: obj, key: "count", value: 42)
encoder.add(to: obj, key: "bigNumber", value: Int64(9223372036854775807))

// Floating point (Float, Double)
encoder.add(to: obj, key: "price", value: 19.99)

// Booleans
encoder.add(to: obj, key: "enabled", value: true)

// Dates
encoder.add(to: obj, key: "createdAt", value: Date())
```

### Arrays

```swift
let encoder = YYJsonEncoder()

// Create arrays from Swift arrays
let numbers = encoder.createArray([1, 2, 3, 4, 5])
let names = encoder.createArray(["Alice", "Bob", "Charlie"])

// Or build arrays manually
let customArray = encoder.createArray()
encoder.addToArray(customArray, value: encoder.createString("item1"))
encoder.addToArray(customArray, value: encoder.createInt(42))
```

### Optional Values

```swift
let encoder = YYJsonEncoder()
let obj = encoder.createObject()

let name: String? = "John"
let nickname: String? = nil

// Omit key if nil
encoder.add(to: obj, key: "name", value: name)       // included
encoder.add(to: obj, key: "nickname", value: nickname) // omitted

// Or encode nil as JSON null
encoder.addOrNull(to: obj, key: "nickname", value: nickname) // "nickname": null
```

### Custom Types with YYJsonEncodable

Conform your types to `YYJsonEncodable` for seamless encoding:

```swift
struct User: YYJsonEncodable {
    let id: Int
    let name: String
    let email: String?

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "id", value: id)
        encoder.add(to: obj, key: "name", value: name)
        encoder.add(to: obj, key: "email", value: email)
        return obj
    }
}

let encoder = YYJsonEncoder()
let user = User(id: 1, name: "Alice", email: "alice@example.com")

let json = try encoder.encode(user)
// {"id":1,"name":"Alice","email":"alice@example.com"}
```

### Nested Objects and Arrays

```swift
struct Address: YYJsonEncodable {
    let street: String
    let city: String

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "street", value: street)
        encoder.add(to: obj, key: "city", value: city)
        return obj
    }
}

struct Person: YYJsonEncodable {
    let name: String
    let addresses: [Address]

    func encode(to encoder: YYJsonEncoder) -> ValueRef {
        let obj = encoder.createObject()
        encoder.add(to: obj, key: "name", value: name)
        encoder.add(to: obj, key: "addresses", value: encoder.createArray(addresses))
        return obj
    }
}
```

## Configuration

### Key Encoding Strategy

```swift
let encoder = YYJsonEncoder()

// Default: use keys as-is
encoder.keyEncodingStrategy = .useDefaultKeys

// Convert camelCase to snake_case
encoder.keyEncodingStrategy = .convertToSnakeCase
// "userName" -> "user_name"

// Custom transformation
encoder.keyEncodingStrategy = .custom { key in
    key.uppercased()
}
```

### Date Encoding Strategy

```swift
let encoder = YYJsonEncoder()

// Unix timestamp (seconds since 1970) - default
encoder.dateEncodingStrategy = .secondsSince1970

// Milliseconds since 1970
encoder.dateEncodingStrategy = .millisecondsSince1970

// ISO8601 string format
encoder.dateEncodingStrategy = .iso8601

// Custom format
encoder.dateEncodingStrategy = .custom { date in
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
```

### Output Formatting

```swift
let encoder = YYJsonEncoder()

// Pretty print with 4-space indent
encoder.outputFormatting = .prettyPrinted

// Pretty print with 2-space indent
encoder.outputFormatting = .prettyPrintedTwoSpaces

// Escape unicode characters to ASCII
encoder.outputFormatting = .escapeUnicode

// Add newline at end of output
encoder.outputFormatting = .newlineAtEnd

// Combine options
encoder.outputFormatting = [.prettyPrinted, .newlineAtEnd]
```

## API Reference

### YYJsonEncoder

| Method | Description |
|--------|-------------|
| `createObject()` | Create a new JSON object |
| `createArray()` | Create a new JSON array |
| `createArray<T: YYJsonEncodable>(_ values: [T])` | Create array from Swift array |
| `add(to:key:value:)` | Add value to object (generic) |
| `add(to:key:value:)` | Add optional value, omitting if nil |
| `addOrNull(to:key:value:)` | Add optional value, encoding nil as null |
| `addToArray(_:value:)` | Append value to array |
| `encode<T: YYJsonEncodable>(_:)` | Encode value to JSON String (auto-resets) |
| `encodeData<T: YYJsonEncodable>(_:)` | Encode value to Data (auto-resets) |

### YYJsonEncodable Protocol

```swift
public protocol YYJsonEncodable {
    func encode(to encoder: YYJsonEncoder) -> ValueRef
}
```

Built-in conformances: `String`, `Bool`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Float`, `Double`, `Date`, `ValueRef`

