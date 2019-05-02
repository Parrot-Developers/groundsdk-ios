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
@testable import GroundSdk

/// Mock http session
class MockHttpSession: HttpSessionCore {

    /// Queue of tasks
    private(set) var tasks: [MockUrlSessionTask] = []

    /// Constructor
    init() {
        super.init(sessionConfiguration: .default)
    }

    override func sendFile(
        request: URLRequest, method: SendMethod = .put, fileUrl: URL,
        progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: Result, _ data: Data?) -> Void) -> CancelableCore {

        let task = MockUploadTask(request: request, fileUrl: fileUrl, progress: progress, completion: completion)
        tasks.append(task)

        return task
    }

    override func getData(request: URLRequest, completion: @escaping (Result, Data?) -> Void) -> CancelableCore {
        let task = MockDataTask(request: request, completion: completion)
        tasks.append(task)

        return task
    }

    override func sendData(
        request: URLRequest, method: HttpSessionCore.SendMethod,
        completion: @escaping (HttpSessionCore.Result, Data?) -> Void) -> CancelableCore {

        let task = MockDataTask(request: request, completion: completion)
        tasks.append(task)

        return task
    }

    override func downloadFile(
        request: URLRequest, destination: URL, progress: @escaping (Int) -> Void,
        completion: @escaping (Result, URL?) -> Void) -> CancelableCore {

        let task = MockDownloadTask(
            request: request, destination: destination, progress: progress, completion: completion)
        tasks.append(task)

        return task
    }

    override func downloadFile(
        streamDecoder: StreamDecoder, request: URLRequest, destination: URL,
        completion: @escaping (Result, URL?) -> Void) -> CancelableCore {

        let task = MockStreamDownloadTask(request: request, destination: destination, completion: completion)
        tasks.append(task)

        return task
    }

    override func delete(request: URLRequest, completion: @escaping (Result) -> Void) -> CancelableCore {
        let task = MockDataTask(request: request) { result, _ in
            completion(result)
        }
        tasks.append(task)

        return task
    }

    /// Pops the last task from the task queue
    ///
    /// - Returns: a MockUrlSessionTask if it exists
    func popLastTask() -> MockUrlSessionTask? {
        return tasks.popLast()
    }
}

/// Mocks a URLSessionTask
class MockUrlSessionTask: CancelableCore {
    /// number of calls to the cancel function
    private(set) var cancelCalls = 0

    let request: URLRequest

    /// Constructor
    ///
    /// - Parameter request: the request to use
    init(request: URLRequest) {
        self.request = request
    }

    func cancel() {
        cancelCalls += 1
        // Nothing to do because we don't want the task to complete synchronously, so we let tester to mock the response
    }
}

/// Mocks a URLSessionDataTask
class MockDataTask: MockUrlSessionTask {
    /// Completion callback
    private let completion: (HttpSessionCore.Result, Data?) -> Void

    /// Constructor
    ///
    /// - Parameters:
    ///   - request: the request to use
    ///   - completion: completion callback
    ///   - result: the http session result
    init(request: URLRequest, completion: @escaping (_ result: HttpSessionCore.Result, _ data: Data?) -> Void) {
        self.completion = completion
        super.init(request: request)
    }

    /// Mocks a request completion success
    ///
    /// - Parameter data: the data received
    func mockCompletionSuccess(data: Data?) {
        completion(.success(200), data)
    }

    // Mocks a request completion fail
    ///
    /// - Parameter statusCode: the status code received
    func mockCompletionFail(statusCode: Int) {
        guard statusCode != 200 else {
            preconditionFailure("Status code for a completion failure should be different from 200")
        }
        completion(.httpError(statusCode), nil)
    }

    /// Mocks an error
    ///
    /// - Parameter error: the error received
    func mock(error: Error) {
        if error as NSError == HttpSessionCore.canceledError {
            completion(.canceled, nil)
        } else {
            completion(.error(error), nil)
        }
    }
}

/// Mocks a URLSessionUploadTask
class MockUploadTask: MockUrlSessionTask {
    /// URL of the file that is uploaded
    let fileUrl: URL
    /// Progress callback
    private let progress: (Int) -> Void
    /// Completion callback
    fileprivate let completion: (HttpSessionCore.Result, Data?) -> Void

    /// Constructor
    ///
    /// - Parameters:
    ///   - request: the request to use
    ///   - fileUrl: url of the local file to upload
    ///   - completion: completion callback
    ///   - result: the http session result
    init(request: URLRequest, fileUrl: URL, progress: @escaping (Int) -> Void,
         completion: @escaping (_ result: HttpSessionCore.Result, _ data: Data?) -> Void) {
        self.fileUrl = fileUrl
        self.progress = progress
        self.completion = completion
        super.init(request: request)
    }

    /// Mocks a progress change
    ///
    /// - Parameter progress: the new progress (in percentage)
    func mock(progress: Int) {
        self.progress(progress)
    }

    /// Mocks a request completion with Data
    ///
    /// - Parameter statusCode: the status code received
    func mockCompletion(statusCode: Int, data: Data? = nil) {
        if statusCode == 200 {
            completion(.success(statusCode), data )
        } else {
            completion(.httpError(statusCode), nil)
        }
    }

    /// Mocks an error
    ///
    /// - Parameter error: the error received
    func mock(error: Error) {
        if error as NSError == HttpSessionCore.canceledError {
            completion(.canceled, nil)
        } else {
            completion(.error(error), nil)
        }
    }
}

/// Mocks a URLSessionDownloadTask
class MockDownloadTask: MockUrlSessionTask {
    /// File download destination
    let destination: URL
    /// Progress callback
    private let progress: (Int) -> Void
    /// Completion callback
    private let completion: (HttpSessionCore.Result, URL?) -> Void

    /// Constructor
    ///
    /// - Parameters:
    ///   - api: the api to use
    ///   - destination: file download destination
    ///   - completion: completion callback
    ///   - result: the http session result
    init(request: URLRequest, destination: URL, progress: @escaping (Int) -> Void,
         completion: @escaping (_ result: HttpSessionCore.Result, _ localFileUrl: URL?) -> Void) {
        self.destination = destination
        self.progress = progress
        self.completion = completion
        super.init(request: request)
    }

    /// Mocks a progress change
    ///
    /// - Parameter progress: the new progress (in percentage)
    func mock(progress: Int) {
        self.progress(progress)
    }

    /// Mocks a request completion success
    ///
    /// - Parameter localFileUrl: the local file url. Nil mocks a file copy error.
    func mockCompletionSuccess(localFileUrl: URL?) {
        completion(.success(200), localFileUrl)
    }

    // Mocks a request completion fail
    ///
    /// - Parameter statusCode: the status code received
    func mockCompletionFail(statusCode: Int) {
        guard statusCode != 200 else {
            preconditionFailure("Status code for a completion failure should be different from 200")
        }
        completion(.httpError(statusCode), nil)
    }

    /// Mocks an error
    ///
    /// - Parameter error: the error received
    func mock(error: Error) {
        if error as NSError == HttpSessionCore.canceledError {
            completion(.canceled, nil)
        } else {
            completion(.error(error), nil)
        }
    }
}

/// Mocks a URLSessionDownloadTask
class MockStreamDownloadTask: MockUrlSessionTask {
    /// File download destination
    let destination: URL

    /// Completion callback
    private let completion: (HttpSessionCore.Result, URL?) -> Void

    /// Constructor
    ///
    /// - Parameters:
    ///   - api: the api to use
    ///   - destination: file download destination
    ///   - completion: completion callback
    ///   - result: the http session result
    init(request: URLRequest, destination: URL,
         completion: @escaping (_ result: HttpSessionCore.Result, _ localFileUrl: URL?) -> Void) {
        self.destination = destination
        self.completion = completion
        super.init(request: request)
    }

    /// Mocks a request completion success
    ///
    /// - Parameter localFileUrl: the local file url. Nil mocks a file copy error.
    func mockCompletionSuccess(localFileUrl: URL?) {
        completion(.success(200), localFileUrl)
    }

    // Mocks a request completion fail
    ///
    /// - Parameter statusCode: the status code received
    func mockCompletionFail(statusCode: Int) {
        guard statusCode != 200 else {
            preconditionFailure("Status code for a completion failure should be different from 200")
        }
        completion(.httpError(statusCode), nil)
    }

    /// Mocks an error
    ///
    /// - Parameter error: the error received
    func mock(error: Error) {
        if error as NSError == HttpSessionCore.canceledError {
            completion(.canceled, nil)
        } else {
            completion(.error(error), nil)
        }
    }
}
