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

import GroundSdk

func has(totalMediaCount: Int) -> Matcher<MediaDownloader> {
    return Matcher("totalMedia = \(totalMediaCount)") { $0.totalMediaCount == totalMediaCount }
}

func has(currentMediaCount: Int) -> Matcher<MediaDownloader> {
    return Matcher("currentMedias = \(currentMediaCount)") { $0.currentMediaCount == currentMediaCount }
}

func has(totalResourceCount: Int) -> Matcher<MediaDownloader> {
    return Matcher("totalResources = \(totalResourceCount)") { $0.totalResourceCount == totalResourceCount }
}

func has(currentResourceCount: Int) -> Matcher<MediaDownloader> {
    return Matcher("currentResources = \(currentResourceCount)") { $0.currentResourceCount == currentResourceCount }
}

func has(currentFileProgress: Float) -> Matcher<MediaDownloader> {
    return Matcher("currentFileProgress = \(currentFileProgress)") { $0.currentFileProgress == currentFileProgress }
}

func has(totalProgress: Float) -> Matcher<MediaDownloader> {
    return Matcher("totalProgress = \(totalProgress)") { $0.totalProgress == totalProgress }
}

func has(fileUrl: URL? = nil) -> Matcher<MediaDownloader> {
    return Matcher("fileUrl = \(String(describing: fileUrl?.absoluteString))")
        { $0.fileUrl?.absoluteString == fileUrl?.absoluteString }
}

func has(status: MediaTaskStatus) -> Matcher<MediaDownloader> {
    return Matcher("status = \(status)") { $0.status == status }
}
