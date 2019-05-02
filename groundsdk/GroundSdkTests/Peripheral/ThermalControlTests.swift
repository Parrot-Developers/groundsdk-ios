// Copyright (C) 2019 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import XCTest
@testable import GroundSdk

/// Test thermal control peripheral
class ThermalControlTests: XCTestCase {

    private var store: ComponentStoreCore!
    private var impl: ThermalControlCore!
    private var backend: Backend!

    override func setUp() {
        super.setUp()
        store = ComponentStoreCore()
        backend = Backend()
        impl = ThermalControlCore(store: store!, backend: backend!)
    }

    func testPublishUnpublish() {
        impl.publish()
        assertThat(store!.get(Peripherals.thermalControl), present())
        impl.unpublish()
        assertThat(store!.get(Peripherals.thermalControl), nilValue())
    }

    func testMode() {
        impl.publish()
        var cnt = 0
        let thermalControl = store.get(Peripherals.thermalControl)!
        _ = store.register(desc: Peripherals.thermalControl) {
            cnt += 1
        }

        // test initial value
        assertThat(thermalControl.setting, supports(modes: []))
        assertThat(thermalControl.setting, `is`(mode: .disabled, updating: false))

        // change capabilities
        impl.update(supportedModes: [.disabled, .standard]).notifyUpdated()
        assertThat(cnt, `is`(1))
        assertThat(thermalControl.setting, supports(modes: [.disabled, .standard]))

        // change mode
        impl.update(mode: .standard).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(thermalControl.setting, `is`(mode: .standard, updating: false))

        // same mode should not change count
        impl.update(mode: .standard).notifyUpdated()
        assertThat(cnt, `is`(2))
        assertThat(thermalControl.setting, `is`(mode: .standard, updating: false))
    }

    func testEmissivity() {
        impl.publish()
        var cnt = 0
        let thermalControl = store.get(Peripherals.thermalControl)!
        _ = store.register(desc: Peripherals.thermalControl) {
            cnt += 1
        }

        thermalControl.sendEmissivity(0.5)
        assertThat(backend.emissivity, `is`(0.5))

        thermalControl.sendEmissivity(-0.5)
        assertThat(backend.emissivity, `is`(0.0))

        thermalControl.sendEmissivity(1.3)
        assertThat(backend.emissivity, `is`(1.0))
    }

    func testBackgroundTemperature() {
        impl.publish()
        var cnt = 0
        let thermalControl = store.get(Peripherals.thermalControl)!
        _ = store.register(desc: Peripherals.thermalControl) {
            cnt += 1
        }

        thermalControl.sendBackgroundTemperature(300)
        assertThat(backend.backgroundTemperature, `is`(300))

        thermalControl.sendBackgroundTemperature(150)
        assertThat(backend.backgroundTemperature, `is`(150))
    }

    func testRendering() {
        impl.publish()
        var cnt = 0
        let thermalControl = store.get(Peripherals.thermalControl)!
        _ = store.register(desc: Peripherals.thermalControl) {
            cnt += 1
        }

        thermalControl.sendRendering(rendering: ThermalRendering(mode: .visible, blendingRate: 0.5))
        assertThat(backend.rendering, presentAnd(`is`(mode: .visible, blendingRate: 0.5)))

        thermalControl.sendRendering(rendering: ThermalRendering(mode: .blended, blendingRate: 0.8))
        assertThat(backend.rendering, presentAnd(`is`(mode: .blended, blendingRate: 0.8)))
    }

    func testSendPalette() {
        impl.publish()
        var cnt = 0
        let thermalControl = store.get(Peripherals.thermalControl)!
        _ = store.register(desc: Peripherals.thermalControl) {
            cnt += 1
        }

        // test initial value
        assertThat(backend.palette, nilValue())

        // absolute palette
        var colors = [ThermalColor(0, 0.1, 0.2, 0), ThermalColor(0.3, -0.5, 1.5, 0.9), ThermalColor(0, -1, 1, 2)]
        var palette: ThermalPalette
        palette = ThermalAbsolutePalette(colors: colors, lowestTemp: 0, highestTemp: 100,
                                         outsideColorization: .limited)
        thermalControl.sendPalette(palette)

        assertThat(backend.palette as? ThermalAbsolutePalette, presentAnd(`is`(0, 100, .limited,
                                                                               [ThermalColor(0, 0.1, 0.2, 0),
                                                                                ThermalColor(0.3, 0, 1, 0.9),
                                                                                ThermalColor(0, 0, 1, 1)])))
        assertThat(cnt, `is`(0))

        // relative palette
        colors = [ThermalColor(-10.1, 0.6, 0.7, 0), ThermalColor(0.8, 1.6, -1.5, 0.91), ThermalColor(10, -2, 0.9, 1)]
        palette = ThermalRelativePalette(colors: colors, locked: true,
                                         lowestTemp: 10, highestTemp: 90)
        thermalControl.sendPalette(palette)

        assertThat(backend.palette as? ThermalRelativePalette, presentAnd(`is`(true, 10, 90,
                                                                               [ThermalColor(0, 0.6, 0.7, 0),
                                                                                ThermalColor(0.8, 1, 0, 0.91),
                                                                                ThermalColor(1, 0, 0.9, 1)])))
        assertThat(cnt, `is`(0))

        // spot palette
        colors = [ThermalColor(1, 1, 0, 0), ThermalColor(1, 1, 1, 1)]
        palette = ThermalSpotPalette(colors: colors, type: .cold, threshold: 123)
        thermalControl.sendPalette(palette)

        assertThat(backend.palette as? ThermalSpotPalette, presentAnd(`is`(.cold, 123,
                                                                           [ThermalColor(1, 1, 0, 0),
                                                                            ThermalColor(1, 1, 1, 1)])))
        assertThat(cnt, `is`(0))
    }

    func testSensitivityRange() {
        impl.publish()
        var cnt = 0
        let thermalControl = store.get(Peripherals.thermalControl)!
        _ = store.register(desc: Peripherals.thermalControl) {
            cnt += 1
        }
        assertThat(backend.range, `is`(.high))
        assertThat(thermalControl.sensitivitySetting, `is`(sensitivityRange: .high, updating: false))

        thermalControl.sensitivitySetting.sensitivityRange = .low
        assertThat(backend.range, `is`(.low))
        assertThat(thermalControl.sensitivitySetting, `is`(sensitivityRange: .low, updating: true))
        impl.update(range: .low).notifyUpdated()
        assertThat(thermalControl.sensitivitySetting, `is`(sensitivityRange: .low, updating: false))

        thermalControl.sensitivitySetting.sensitivityRange = .high
        assertThat(backend.range, `is`(.high))
        assertThat(thermalControl.sensitivitySetting, `is`(sensitivityRange: .high, updating: true))
        impl.update(range: .high).notifyUpdated()
        assertThat(thermalControl.sensitivitySetting, `is`(sensitivityRange: .high, updating: false))

        thermalControl.sensitivitySetting.sensitivityRange = .high
        assertThat(backend.range, `is`(.high))
        assertThat(thermalControl.sensitivitySetting, `is`(sensitivityRange: .high, updating: false))
    }
}

private class Backend: ThermalControlBackend {

    var emissivity: Double?
    var backgroundTemperature: Double?
    var mode: ThermalControlMode?
    var palette: ThermalPalette?
    var rendering: ThermalRendering?
    var range: ThermalSensitivityRange = .high

    func set(emissivity: Double) {
        self.emissivity = emissivity
    }

    func set(backgroundTemperature: Double) {
        self.backgroundTemperature = backgroundTemperature
    }

    func set(mode: ThermalControlMode) -> Bool {
        self.mode = mode
        return true
    }

    func set(range: ThermalSensitivityRange) -> Bool {
        self.range = range
        return true
    }

    func set(rendering: ThermalRendering) {
        self.rendering = rendering
    }

    func set(palette: ThermalPalette) {
        self.palette = palette
    }
}
