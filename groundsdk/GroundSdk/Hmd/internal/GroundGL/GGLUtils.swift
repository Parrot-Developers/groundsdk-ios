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
import UIKit
import GLKit

/// Timer using a GCD DispatchSource Timer
public class GGLTimer {

    /// Timer's state
    private enum State {
        case suspended
        case resumed
    }

    private let fireQueue: DispatchQueue

    private let timeInterval: TimeInterval

    /// private Timer dispatch source. The event handler will be fired on the specified queue.
    private lazy var timer: DispatchSourceTimer = {
        let timerSource = DispatchSource.makeTimerSource(queue: self.fireQueue)
        timerSource.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        timerSource.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return timerSource
    }()

    /// Current sate of the timer
    private var state: State = .suspended

    var eventHandler: (() -> Void)?

    /// Contructor
    /// Creates a repeating timer
    ///
    /// Note: a `eventHandler` closure property can ben set to the timer. Use `resume()` and `suspend()`functions
    ///  in order to start / stop the timer.
    /// - Parameters:
    ///   - timeInterval: repeating time interval (seconds)
    ///   - fireQueue: GCD queue target. Default is .main
    init(timeInterval: TimeInterval, fireQueue: DispatchQueue? = nil) {
        if let fireQueue = fireQueue {
            self.fireQueue = fireQueue
        } else {
            self.fireQueue = DispatchQueue.main
        }
        self.timeInterval = timeInterval
    }

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming triggers a crash.
         */
        // add resume
        resume()
        eventHandler = nil
    }

    /// Resumes the timer.
    func resume() {
        guard state != .resumed else {
            return
        }
        state = .resumed
        timer.resume()
    }

    /// Suspend (stop) the timer
    func suspend() {
        guard state != .suspended else {
            return
        }
        state = .suspended
        timer.suspend()
    }
}

/// various utilities used in the HMD / GoundGL functions
class GGLUtils {
    /// Search a `DrawableView` in a hierarchy of views
    ///
    /// - Parameter view: The root view in the hierarchy
    /// - Returns: The first `DrawableView` found in the hierarchy. If any, returns `nil`
    static func getDrawableView (view: UIView) -> UIView? {
        if view is DrawableView {
            return view
        } else if view.subviews.count > 0 {
            for aView in view.subviews {
                if let resultView = getDrawableView(view: aView) {
                    return resultView
                }
            }
        }
        return nil
    }
    static func getTextureIdFromView(view: UIView) -> GLuint {
        var retId = GLuint()
        let viewToDraw: UIView = getDrawableView(view: view) ?? view

        // uses the 'WithOptions' in order to get the maximum resolution
        // low res version : UIGraphicsBeginImageContext(view.frame.size)
        UIGraphicsBeginImageContextWithOptions(viewToDraw.frame.size, false, 0 )

        if let context = UIGraphicsGetCurrentContext() {
            viewToDraw.layer.render(in: context)
            if let image = UIGraphicsGetImageFromCurrentImageContext(),
                let cgimage = image.cgImage,
                let textureInfo = try? GLKTextureLoader.texture(with: cgimage) {
                retId = textureInfo.name
            }
        }
        UIGraphicsEndImageContext()
        return retId
    }
}
