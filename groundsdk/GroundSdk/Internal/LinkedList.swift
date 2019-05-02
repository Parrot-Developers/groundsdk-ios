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

import Foundation

/// A node of a list
/// T: node data
class LinkedListNode<T> {
    /// Next node in the list
    fileprivate var next: LinkedListNode?
    /// Previous node
    fileprivate weak var prev: LinkedListNode?
    /// Node content
    var content: T?

    /// Constructor
    init() {
    }

    /// Constructor with an initial content
    ///
    /// - Parameter content: initial content
    init(content: T) {
        self.content = content
    }
}

/// A Double linked list
/// T: List entry type
class LinkedList<T> {

    /// Root node
    private let list = LinkedListNode<T>()

    /// Constructor
    init() {
        list.next = list
        list.prev = list
    }

    /// Push a node on the list head
    ///
    /// - Parameter node: note to push. It will become the first element of the list.
    func push(_ node: LinkedListNode<T>) {
        list.next?.prev = node
        node.next = list.next
        node.prev = list
        list.next = node
    }

    /// Pop the node on the list head
    ///
    /// - Returns: first node, nil if the list is empty
    func pop() ->  LinkedListNode<T>? {
        let node = list.next
        if node !== list {
            remove(node!)
            return node
        }
        return nil
    }

    /// Queue a node at the tail of the list
    ///
    /// - Parameter node: node to queue. It will become the last element of the list
    func queue(_ node: LinkedListNode<T>) {
        list.prev!.next = node
        node.next = list
        node.prev = list.prev
        list.prev = node
    }

    /// Remove a node from the list
    ///
    /// - Parameter node: node to remove
    func remove(_ node: LinkedListNode<T>) {
         if let next = node.next, let prev = node.prev {
            next.prev = prev
            prev.next = next
            node.prev = nil
            node.next = nil
        }
    }

    /// Walk through the list in forward order
    ///
    /// - Parameter until: closure called for each node, while it return true
    func walk(while: (LinkedListNode<T>) -> Bool) {
        var node = list.next!
        // preload next to allow closure to remove current node
        var next = node.next!
        while node !== list && `while`(node) {
            node = next
            next = node.next!
        }
    }

    /// Walk through the list in reverse order
    ///
    /// - Parameter until: closure called for each node, while it return true
    func reverseWalk(while: (LinkedListNode<T>) -> Bool) {
        var node = list.prev!
        // preload previous to allow closure to remove current node
        var prev = node.prev!
        while node !== list && `while`(node) {
            node = prev
            prev = node.prev!
        }
    }

    /// Remove all items from the list
    func reset() {
        list.next = list
        list.prev = list
    }
}
