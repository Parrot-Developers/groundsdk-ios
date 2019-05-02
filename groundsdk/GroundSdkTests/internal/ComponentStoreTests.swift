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

class ComponentStoreCoreTests: XCTestCase {

    var componentStore: ComponentStoreCore?

    override func setUp() {
        super.setUp()
        componentStore = ComponentStoreCore()
    }

    override func tearDown() {
        super.tearDown()
        componentStore = nil
    }

    func testAddComponent() {
        var didChangeCnt = 0
        let listener = componentStore!.register(desc: mainComDesc, didChange: {
            didChangeCnt += 1
        })
        assertThat(didChangeCnt, `is`(0))

        // add component, check listener notified
        let comp = MainCompImpl()
        componentStore!.add(comp)
        assertThat(didChangeCnt, `is`(1))

        // get component, check its expected class
        var mainComp = componentStore!.get(mainComDesc)
        assertThat(mainComp, present())
        assertThat(mainComp!.mainFunc(), `is`("mainFunc"))

        // remove component, check notified
        componentStore!.remove(comp)
        assertThat(didChangeCnt, `is`(2))

        // get component, check is nil
        mainComp = componentStore!.get(mainComDesc)
        assertThat(mainComp, nilValue())

        componentStore!.unregister(listener: listener)
    }

    func testComponentListenerObservers() {
        var countFirstListener = 0
        var countNoMoreListener = 0

        // add component, check callbacks
        let comp = SubCompImpl(
            didRegisterFirstListenerCallback: {
                countFirstListener += 1
        },
            didUnregisterLastListenerCallback: {
                countNoMoreListener += 1
        })
        componentStore!.add(comp)

        // no listener
        assertThat(countFirstListener, `is`(0))
        assertThat(countNoMoreListener, `is`(0))
        // 1 listener ->  check callback `didRegisterFirstListenerCallback
        let listener = componentStore!.register(desc: subComDesc, didChange: {})
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))

        // add more listeners -> no callback
        let listener2 = componentStore!.register(desc: subComDesc, didChange: {})
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))

        // add more listener (a listener to the parent)
        let listener3 = componentStore!.register(desc: mainComDesc, didChange: {})
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))

        // remove some listeners (but keep one) -> no callback
        componentStore!.unregister(listener: listener2)
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))
        componentStore!.unregister(listener: listener)
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))

        // remove the last listener -> check callback `didUnregisterLastListenerCallback
        componentStore!.unregister(listener: listener3)
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(1))

        // get as main component, check `didRegisterFirstListenerCallback` is called
        countFirstListener = 0
        countNoMoreListener = 0
        let listener4 = componentStore!.register(desc: mainComDesc, didChange: {})
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))
        // remove main component listener, check `didUnregisterLastListenerCallback` is called
        componentStore!.unregister(listener: listener4)
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(1))

        // add listener before the component
        countFirstListener = 0
        countNoMoreListener = 0
        componentStore!.remove(comp)
        assertThat(countFirstListener, `is`(0))
        assertThat(countNoMoreListener, `is`(0))
        let subListener = componentStore!.register(desc: subComDesc, didChange: {})
        assertThat(countFirstListener, `is`(0))
        assertThat(countNoMoreListener, `is`(0))
        componentStore!.add(comp)
        // 1 listener ->  check callback `didRegisterFirstListenerCallback
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))
        componentStore!.remove(comp)
        componentStore!.unregister(listener: subListener)

        // add listener on main component before adding sub component
        countFirstListener = 0
        countNoMoreListener = 0
        _ = componentStore!.register(desc: mainComDesc, didChange: {})
        assertThat(countFirstListener, `is`(0))
        assertThat(countNoMoreListener, `is`(0))
        componentStore!.add(comp)
        assertThat(countFirstListener, `is`(1))
        assertThat(countNoMoreListener, `is`(0))
    }

    func testAddSubComponent() {
        var mainDidChangeCnt = 0
        let mainListener = componentStore!.register(desc: mainComDesc, didChange: {
            mainDidChangeCnt += 1
        })
        assertThat(mainDidChangeCnt, `is`(0))

        var subDidChangeCnt = 0
        let subListener = componentStore!.register(desc: subComDesc, didChange: {
            subDidChangeCnt += 1
        })
        assertThat(subDidChangeCnt, `is`(0))

        // add sub component, check main and sub listener notified
        let comp = SubCompImpl()
        componentStore!.add(comp)
        assertThat(mainDidChangeCnt, `is`(1))
        assertThat(subDidChangeCnt, `is`(1))

        // get as main component, check it
        var mainComp = componentStore!.get(mainComDesc)
        assertThat(mainComp, present())
        assertThat(mainComp!.mainFunc(), `is`("mainFunc on sub"))

        // get as sub component, check it
        var subComp = componentStore!.get(subComDesc)
        assertThat(subComp, present())
        assertThat(subComp!.mainFunc(), `is`("mainFunc on sub"))
        assertThat(subComp!.subFunc(), `is`("subFunc"))

        // remove component, check notified
        componentStore!.remove(comp)
        assertThat(mainDidChangeCnt, `is`(2))
        assertThat(subDidChangeCnt, `is`(2))

        // get as main component, check is nil
        mainComp = componentStore!.get(mainComDesc)
        assertThat(mainComp, nilValue())

        // get as sub component, check is nil
        subComp = componentStore!.get(subComDesc)
        assertThat(subComp, nilValue())

        componentStore!.unregister(listener: mainListener)
        componentStore!.unregister(listener: subListener)
    }
}

class ComponentRefCoreTests: XCTestCase {
    var componentStore: ComponentStoreCore?

    override func setUp() {
        super.setUp()
        componentStore = ComponentStoreCore()
    }

    override func tearDown() {
        super.tearDown()
        componentStore = nil
    }

    func testMainComponentRef() {
        var didChangeCnt = 0
        var ref: ComponentRefCore? = ComponentRefCore(store: componentStore!, desc: mainComDesc) { _ in
            didChangeCnt += 1
        }
        assertThat(didChangeCnt, `is`(0))

        // add main component, check notified
        let comp = MainCompImpl()
        componentStore!.add(comp)
        assertThat(didChangeCnt, `is`(1))

        // update component, check notified
        componentStore!.notifyUpdated(comp)
        assertThat(didChangeCnt, `is`(2))

        // remove component, check notified
        componentStore!.remove(comp)
        assertThat(didChangeCnt, `is`(3))

        ref = nil
        // remove unused variable warning
        _ = ref
    }

    func testSubComponentRef() {
        var mainCompDidChangeCnt = 0
        var mainCompRef: ComponentRefCore? = ComponentRefCore(store: componentStore!, desc: subComDesc) { _ in
            mainCompDidChangeCnt += 1
        }
        assertThat(mainCompDidChangeCnt, `is`(0))

        // add sub component, check notified
        let comp = SubCompImpl()
        componentStore!.add(comp)
        assertThat(mainCompDidChangeCnt, `is`(1))

        // update component, check notified
        componentStore!.notifyUpdated(comp)
        assertThat(mainCompDidChangeCnt, `is`(2))

        // remove component, check notified
        componentStore!.remove(comp)
        assertThat(mainCompDidChangeCnt, `is`(3))

        mainCompRef = nil
        // remove unused variable warning
        _ = mainCompRef
    }
}

protocol MainComp: Component {
    func mainFunc() -> String
}

class MainComDesc: NSObject, ComponentApiDescriptor {
    typealias ApiProtocol = MainComp
    let uid = 1
    let parent: ComponentDescriptor? = nil
}
let mainComDesc = MainComDesc()

protocol SubComp: MainComp {
    func subFunc() -> String
}

class SubComDesc: NSObject, ComponentApiDescriptor {
    typealias ApiProtocol = SubComp
    let uid = 2
    let parent: ComponentDescriptor? = mainComDesc
}
let subComDesc = SubComDesc()

class MainCompImpl: ComponentCore, MainComp {
    init(didRegisterFirstListenerCallback: @escaping ListenersDidChangeCallback = {},
         didUnregisterLastListenerCallback: @escaping ListenersDidChangeCallback = {}) {
        super.init(desc: mainComDesc, store: ComponentStoreCore(),
                   didRegisterFirstListenerCallback: didRegisterFirstListenerCallback,
                   didUnregisterLastListenerCallback: didUnregisterLastListenerCallback)
    }

    func mainFunc() -> String {
        return "mainFunc"
    }
}

class SubCompImpl: ComponentCore, SubComp {
    init(didRegisterFirstListenerCallback: @escaping ListenersDidChangeCallback = {},
         didUnregisterLastListenerCallback: @escaping ListenersDidChangeCallback = {}) {
        super.init(desc: subComDesc, store: ComponentStoreCore(),
                   didRegisterFirstListenerCallback: didRegisterFirstListenerCallback,
                   didUnregisterLastListenerCallback: didUnregisterLastListenerCallback)
    }

    func mainFunc() -> String {
        return "mainFunc on sub"
    }
    func subFunc() -> String {
        return "subFunc"
    }
}
