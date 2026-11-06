import Foundation
import IOKit

public final class SMCEngine: @unchecked Sendable {
    public static let shared = SMCEngine()

    private var connection: io_connect_t = 0
    private let lock = NSLock()

    // SMC Command Structs
    private struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCParamStruct {
        var key: UInt32 = 0
        var vers: SMCVersion = SMCVersion()
        var pLimitData: SMCPLimitData = SMCPLimitData()
        var keyInfo: SMCKeyInfoData = SMCKeyInfoData()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0,
                                                                             0, 0, 0, 0, 0, 0, 0, 0,
                                                                             0, 0, 0, 0, 0, 0, 0, 0,
                                                                             0, 0, 0, 0, 0, 0, 0, 0)
    }

    private init() {
        openSMC()
    }

    deinit {
        closeSMC()
    }

    private func openSMC() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        _ = IOServiceOpen(service, mach_task_self_, 0, &connection)
    }

    private func closeSMC() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    private func callSMC(input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
        guard connection != 0 else { return false }
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let kerr = IOConnectCallStructMethod(
            connection,
            2, // kSMCUserClientOpen
            &input,
            inputSize,
            &output,
            &outputSize
        )
        return kerr == KERN_SUCCESS && output.result == 0
    }

    private func fourCharCode(from string: String) -> UInt32 {
        var result: UInt32 = 0
        for char in string.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }

    public func readNumber(key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }

        guard connection != 0 else { return nil }

        let keyCode = fourCharCode(from: key)
        var input = SMCParamStruct()
        var output = SMCParamStruct()

        // 1. Get Key Info
        input.key = keyCode
        input.data8 = 9 // SMC_CMD_READ_KEYINFO
        guard callSMC(input: &input, output: &output) else { return nil }

        let info = output.keyInfo
        let size = Int(info.dataSize)
        let typeCode = info.dataType

        // 2. Read Key Value
        input.key = keyCode
        input.keyInfo.dataSize = info.dataSize
        input.data8 = 5 // SMC_CMD_READ_BYTES
        guard callSMC(input: &input, output: &output) else { return nil }

        let bytesTuple = output.bytes
        let bytes: [UInt8] = withUnsafeBytes(of: bytesTuple) { Array($0.prefix(size)) }
        guard bytes.count == size else { return nil }

        // Decode based on type
        // 'sp78' = 0x73703738 (Signed 8.8 fixed point)
        if typeCode == 0x73703738 && size == 2 {
            let raw = (Int16(bytes[0]) << 8) | Int16(bytes[1])
            return Double(raw) / 256.0
        }
        // 'fpe2' = 0x66706532 (Unsigned 14.2 fixed point)
        if typeCode == 0x66706532 && size == 2 {
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        }
        // 'flt ' = 0x666c7420 (Float32)
        if typeCode == 0x666c7420 && size == 4 {
            let u32 = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            return Double(Float(bitPattern: u32))
        }
        // 'ui8 '
        if typeCode == 0x75693820 && size == 1 {
            return Double(bytes[0])
        }
        // 'ui16'
        if typeCode == 0x75693136 && size == 2 {
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw)
        }

        return nil
    }
}
