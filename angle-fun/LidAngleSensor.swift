//
//  LidAngleSensor.swift
//  angle-fun
//
//  Created by Codex on 3/26/26.
//

import Foundation
import Combine
import IOKit.hid

final class HIDLidAngleSensor {
    private let manager: IOHIDManager
    private var device: IOHIDDevice?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        let matchers: [[String: Any]] = [
            [
                kIOHIDVendorIDKey as String: 0x05AC,
                kIOHIDProductIDKey as String: 0x8104,
                kIOHIDDeviceUsagePageKey as String: 0x20,
                kIOHIDDeviceUsageKey as String: 0x8A
            ],
            [
                kIOHIDVendorIDKey as String: 0x05AC,
                kIOHIDDeviceUsagePageKey as String: 0x20,
                kIOHIDDeviceUsageKey as String: 0x8A
            ],
            [
                kIOHIDDeviceUsagePageKey as String: 0x20,
                kIOHIDDeviceUsageKey as String: 0x8A
            ]
        ]

        for matcher in matchers {
            if let found = findWorkingDevice(matching: matcher) {
                device = found
                break
            }
        }

        if let device {
            _ = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    deinit {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func currentAngle() -> Int? {
        guard let device else { return nil }

        var report = [UInt8](repeating: 0, count: 8)
        var length: CFIndex = report.count
        let result = report.withUnsafeMutableBufferPointer { buffer in
            guard let pointer = buffer.baseAddress else { return kIOReturnError }
            return IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                CFIndex(1),
                pointer,
                &length
            )
        }

        guard result == kIOReturnSuccess, length >= 3 else {
            return nil
        }

        return Int(report[1]) | (Int(report[2]) << 8)
    }

    private func findWorkingDevice(matching: [String: Any]) -> IOHIDDevice? {
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard let devices = IOHIDManagerCopyDevices(manager) else {
            return nil
        }

        let count = CFSetGetCount(devices)
        var values = Array<UnsafeRawPointer?>(repeating: nil, count: count)
        CFSetGetValues(devices, &values)

        for rawValue in values {
            guard let rawValue else { continue }
            let device = unsafeBitCast(rawValue, to: IOHIDDevice.self)
            guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
                continue
            }

            var report = [UInt8](repeating: 0, count: 8)
            var length: CFIndex = report.count
            let result = report.withUnsafeMutableBufferPointer { buffer in
                guard let pointer = buffer.baseAddress else { return kIOReturnError }
                return IOHIDDeviceGetReport(
                    device,
                    kIOHIDReportTypeFeature,
                    CFIndex(1),
                    pointer,
                    &length
                )
            }

            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))

            if result == kIOReturnSuccess, length >= 3 {
                return device
            }
        }

        return nil
    }
}

final class LidAngleViewModel: ObservableObject {
    @Published private(set) var displayText = "—°"

    private let sensor = HIDLidAngleSensor()
    private let pollQueue = DispatchQueue(label: "com.angle-fun.lid-angle")
    private var timer: DispatchSourceTimer?

    func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(120))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let angle = self.sensor.currentAngle()
            DispatchQueue.main.async {
                if let angle {
                    self.displayText = "\(angle)°"
                } else {
                    self.displayText = "—°"
                }
            }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }
}
