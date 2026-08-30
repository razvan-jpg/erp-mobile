import Foundation
import Compression

/// Citire minimală ZIP (STORE + DEFLATE) — pentru import .xlsx.
enum ZipReader {
    static func extract(entryPath: String, from zipData: Data) throws -> Data {
        guard let eocdOffset = findEOCD(in: zipData) else {
            throw ZipReadError.invalidArchive
        }
        let totalEntries = Int(readU16(zipData, eocdOffset + 10))
        let centralOffset = Int(readU32(zipData, eocdOffset + 16))
        var offset = centralOffset

        for _ in 0..<totalEntries {
            guard readU32(zipData, offset) == 0x02014b50 else { break }
            let method = readU16(zipData, offset + 10)
            let compSize = Int(readU32(zipData, offset + 20))
            let uncompSize = Int(readU32(zipData, offset + 24))
            let nameLen = Int(readU16(zipData, offset + 28))
            let extraLen = Int(readU16(zipData, offset + 30))
            let commentLen = Int(readU16(zipData, offset + 32))
            let localOffset = Int(readU32(zipData, offset + 42))
            let nameStart = offset + 46
            guard nameStart + nameLen <= zipData.count else { break }
            let name = String(data: zipData[nameStart..<(nameStart + nameLen)], encoding: .utf8) ?? ""
            offset = nameStart + nameLen + extraLen + commentLen

            guard name == entryPath || name.hasSuffix("/\(entryPath)") else { continue }

            guard readU32(zipData, localOffset) == 0x04034b50 else {
                throw ZipReadError.invalidEntry
            }
            let localNameLen = Int(readU16(zipData, localOffset + 26))
            let localExtraLen = Int(readU16(zipData, localOffset + 28))
            let dataStart = localOffset + 30 + localNameLen + localExtraLen
            guard dataStart + compSize <= zipData.count else {
                throw ZipReadError.invalidEntry
            }
            let compressed = zipData[dataStart..<(dataStart + compSize)]
            if method == 0 {
                return Data(compressed)
            }
            if method == 8 {
                return try inflateRawDeflate(compressed, expectedSize: uncompSize)
            }
            throw ZipReadError.unsupportedMethod(method)
        }
        throw ZipReadError.entryNotFound(entryPath)
    }

    static func findEOCD(in data: Data) -> Int? {
        let minEOCD = 22
        guard data.count >= minEOCD else { return nil }
        let searchStart = max(0, data.count - 65_536)
        for i in stride(from: data.count - minEOCD, through: searchStart, by: -1) {
            if readU32(data, i) == 0x06054b50 { return i }
        }
        return nil
    }

    private static func inflateRawDeflate(_ data: Data, expectedSize: Int) throws -> Data {
        let dstCap = max(expectedSize, data.count * 4, 4096)
        var dst = Data(count: dstCap)
        let written: Int = dst.withUnsafeMutableBytes { dstBuf in
            data.withUnsafeBytes { srcBuf in
                guard let src = srcBuf.bindMemory(to: UInt8.self).baseAddress,
                      let dstBase = dstBuf.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    dstBase, dstCap,
                    src, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else { throw ZipReadError.inflateFailed }
        return dst.prefix(written)
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    enum ZipReadError: LocalizedError {
        case invalidArchive
        case invalidEntry
        case entryNotFound(String)
        case unsupportedMethod(UInt16)
        case inflateFailed

        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "Arhivă ZIP invalidă."
            case .invalidEntry: return "Intrare ZIP invalidă."
            case .entryNotFound(let p): return "Lipsește \(p) din arhivă."
            case .unsupportedMethod(let m): return "Metodă ZIP nesuportată: \(m)."
            case .inflateFailed: return "Nu s-a putut decomprima fișierul Excel."
            }
        }
    }
}
