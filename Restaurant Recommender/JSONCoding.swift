//
//  JSONCoding.swift
//  Simple Todo App
//

import Foundation

/// The backend emits timestamps as `2026-06-07T15:46:47.718257Z` — ISO 8601
/// with microsecond fractional seconds. `ISO8601DateFormatter` only supports
/// up to millisecond precision but will still successfully parse (and
/// truncate) longer fractional components. Plain timestamps with no
/// fractional seconds need the non-fractional formatter instead, so we try
/// both.
nonisolated enum APIDateCoding {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        withFractionalSeconds.date(from: string) ?? plain.date(from: string)
    }
}

extension JSONDecoder {
    nonisolated static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = APIDateCoding.parse(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognised date format: \(raw)"
                )
            }
            return date
        }
        return decoder
    }()
}

extension JSONEncoder {
    nonisolated static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
