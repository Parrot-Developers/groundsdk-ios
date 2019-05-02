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

class LinkedListTests: XCTestCase {

    func checkList(list: LinkedList<String>, expected: [String]) {
        var content = expected
        list.walk { node in
            assertThat(node.content!, `is`(content.removeFirst()))
            return true
        }
    }

    func testPush() {
        let list = LinkedList<String>()

        list.push(LinkedListNode(content: "A"))
        checkList(list: list, expected: ["A"])

        list.push(LinkedListNode(content: "B"))
        checkList(list: list, expected: ["B", "A"])

        list.push(LinkedListNode(content: "C"))
        checkList(list: list, expected: ["C", "B", "A"])
    }

    func testQueue() {
        let list = LinkedList<String>()

        list.queue(LinkedListNode(content: "A"))
        checkList(list: list, expected: ["A"])

        list.queue(LinkedListNode(content: "B"))
        checkList(list: list, expected: ["A", "B"])

        list.queue(LinkedListNode(content: "C"))
        checkList(list: list, expected: ["A", "B", "C"])
    }

    func testPop() {
        let list = LinkedList<String>()
        list.queue(LinkedListNode(content: "A"))
        list.queue(LinkedListNode(content: "B"))
        list.queue(LinkedListNode(content: "C"))

        assertThat(list.pop()?.content, presentAnd(`is`("A")))
        assertThat(list.pop()?.content, presentAnd(`is`("B")))
        assertThat(list.pop()?.content, presentAnd(`is`("C")))
        assertThat(list.pop()?.content, nilValue())
    }

    func testRemove() {
        let list = LinkedList<String>()

        let a = LinkedListNode(content: "A")
        let b = LinkedListNode(content: "B")
        let c = LinkedListNode(content: "C")
        list.queue(a)
        list.queue(b)
        list.queue(c)

        list.remove(b)
        checkList(list: list, expected: ["A", "C"])

        list.remove(c)
        checkList(list: list, expected: ["A"])

        list.remove(a)
        checkList(list: list, expected: [])
    }

    func testWalkList() {
        let list = LinkedList<String>()
        list.queue(LinkedListNode(content: "A"))
        list.queue(LinkedListNode(content: "B"))
        list.queue(LinkedListNode(content: "C"))

        var forwardContent = ["A", "B", "C"]
        list.walk { node in
            assertThat(node.content!, `is`(forwardContent.removeFirst()))
            return true
        }

        var reverseContent = ["C", "B", "A"]
        list.reverseWalk { node in
            assertThat(node.content!, `is`(reverseContent.removeFirst()))
            return true
        }
    }
}
