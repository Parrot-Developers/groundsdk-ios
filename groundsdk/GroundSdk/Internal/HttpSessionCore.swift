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

/// An http session that has one URLSession.
public class HttpSessionCore: NSObject {

    /// Send file method
    public enum SendMethod: String {
        /// Send the file with a `PUT` request
        case put = "PUT"
        /// Send the file with a `POST` request
        case post = "POST"
    }

    /// Http session completion result
    public enum Result: CustomStringConvertible {
        /// The request succeed (with the http status code)
        case success(Int)
        /// The request failed due to an http response (with the http status code)
        case httpError(Int)
        /// The request failed due to an error
        case error(Error)
        /// The request has been canceled
        case canceled

        /// Debug description.
        public var description: String {
            switch self {
            case .success(let statusCode):      return "success(\(statusCode))"
            case .httpError(let statusCode):    return "Http error(\(statusCode))"
            case .error(let error):             return "error(\(error))"
            case .canceled:                     return "canceled"
            }
        }
    }

    /// An object representing a download completion callback
    private struct DownloadCompletionCb {
        /// The desired destination of the downloaded file
        let destination: URL
        /// The callback to call when download is complete or fails
        let callback: (_ result: Result, _ localFileUrl: URL?) -> Void
    }

    /// Url session
    private var session: URLSession!
    /// Map of progress callbacks indexed by task identifier
    private var progressCbs: [Int: (Int) -> Void] = [:]
    /// Map of download completion callbacks indexed by task identifier. This dictionary contains call backs for tasks
    /// created with 'downloadFile' function
    private var dlCompletionCbs: [Int: DownloadCompletionCb] = [:]
    /// Map of stream download completion callbacks indexed by task identifier. This dictionary contains call backs for
    /// task created with 'downloadFile(withStreamReader: _)` function
    private var streamDlCompletionCbs: [Int: DownloadCompletionCb] = [:]
    /// Map of streamWriter objects indexed by task identifier. This dictionary contains streamWriter object for
    /// task created with 'downloadFile(withStreamReader: _)` function
    private var streamWriters: [Int: StreamWriter] = [:]

    /// Error raised when request has been canceled
    ///
    /// Visibility is internal for testing purpose.
    static let canceledError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
    /// Default error.
    /// Used when no known error could be matched.
    ///
    /// - Note: We use the HTTP error code 418 to express this unknown default error.
    /// 418 error code is "I'm a teapot" error (which is the best error name ever).
    private static let defaultError = Result.httpError(418)

    /// Constructor
    ///
    /// - Parameter sessionConfiguration: the session configuration
    public init(sessionConfiguration: URLSessionConfiguration) {
        super.init()
        /// An operation queue for scheduling the delegate calls and completion handlers. The queue should is a serial
        /// queue, in order to ensure the correct ordering of callbacks
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: delegateQueue)
    }

    /// Get data
    ///
    /// - Note: The request is started in this function.
    ///
    /// - Parameters:
    ///   - request: request to use
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - data: the data that has been get. `nil` if result is not `.success`
    /// - Returns: the request
    public func getData(
        request: URLRequest, completion: @escaping (_ result: Result, _ data: Data?) -> Void) -> CancelableCore {

        var request = request
        request.httpMethod = "GET"

        var task: URLSessionTask!
        task = session.dataTask(with: request) { data, response, error in

            let result: Result
            if let error = error {
                if error as NSError == HttpSessionCore.canceledError {
                    result = .canceled
                } else {
                    result = .error(error)
                }
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    result = .success(response.statusCode)
                } else {
                    result = .httpError(response.statusCode)
                }
            } else {
                result = HttpSessionCore.defaultError
            }

            // as we are in the delegateQueue, executes the call back in main thread
            DispatchQueue.main.async {
                ULog.d(.httpClientTag, "Task \(task.taskIdentifier) (\(request.url?.description ?? "")) " +
                    "did complete with result: \(result)")
                completion(result, data)
            }

        }
        task.resume()
        return task
    }

    /// Send data
    ///
    /// - Note: The request is started in this function.
    ///
    /// - Parameters:
    ///   - request: request to use
    ///   - method: method to use to send the file. Default is `.put`.
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - data: the data that has been get. `nil` if result is not `.success`
    /// - Returns: the request
    public func sendData(
        request: URLRequest, method: SendMethod = .put,
        completion: @escaping (_ result: Result, _ data: Data?) -> Void) -> CancelableCore {

        var request = request
        request.httpMethod = method.rawValue

        var task: URLSessionTask!
        task = session.dataTask(with: request) { data, response, error in

            let result: Result
            if let error = error {
                if error as NSError == HttpSessionCore.canceledError {
                    result = .canceled
                } else {
                    result = .error(error)
                }
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    result = .success(response.statusCode)
                } else {
                    result = .httpError(response.statusCode)
                }
            } else {
                result = HttpSessionCore.defaultError
            }

            // as we are in the delegateQueue, executes the call back in main thread
            DispatchQueue.main.async {
                ULog.d(.httpClientTag, "Task \(task.taskIdentifier) (\(request.url?.description ?? "")) " +
                    "did complete with result: \(result)")
                completion(result, data)
            }

        }
        task.resume()
        return task
    }

    /// Send a file with a put request
    ///
    /// - Note: The request is started in this function.
    ///
    /// - Parameters:
    ///   - request: request to use
    ///   - method: method to use to send the file. Default is `.put`.
    ///   - fileUrl: local file url
    ///   - progress: progress callback
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - data: data returned in the response body
    /// - Returns: the request
    public func sendFile(
        request: URLRequest, method: SendMethod = .put, fileUrl: URL,
        progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: Result, _ data: Data?) -> Void) -> CancelableCore {

        var request = request
        request.httpMethod = method.rawValue

        var task: URLSessionTask!
        task = session.uploadTask(with: request, fromFile: fileUrl) { data, response, error in

            let result: Result
            if let error = error {
                if error as NSError == HttpSessionCore.canceledError {
                    result = .canceled
                } else {
                    result = .error(error)
                }
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    result = .success(response.statusCode)
                } else {
                    result = .httpError(response.statusCode)
                }
            } else {
                result = HttpSessionCore.defaultError
            }
            // as we are in the delegateQueue, executes the call back in main thread
            DispatchQueue.main.async {
                self.progressCbs[task.taskIdentifier] = nil
                ULog.d(.httpClientTag, "Task \(task.taskIdentifier) (\(request.url?.description ?? "")) " +
                    "did complete with result: \(result)")
                completion(result, data)
            }
        }
        progressCbs[task.taskIdentifier] = progress
        task.resume()

        return task
    }

    /// Download a file with a get request
    ///
    /// - Note: The request is started in this function.
    ///
    /// - Parameters:
    ///   - request: request to use
    ///   - destination: destination local file url
    ///   - progress: progress callback
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - localFileUrl: the local file url of the downloaded file. Note that when the completion closure exits, this
    ///                   local file will deleted.
    /// - Returns: the request
    public func downloadFile(
        request: URLRequest, destination: URL, progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ result: Result, _ localFileUrl: URL?) -> Void) -> CancelableCore {

        var request = request
        request.httpMethod = "GET"

        var task: URLSessionTask!
        task = session.downloadTask(with: request)

        progressCbs[task.taskIdentifier] = progress
        dlCompletionCbs[task.taskIdentifier] = DownloadCompletionCb(destination: destination, callback: completion)
        task.resume()

        return task
    }

    /// Download a file with a get request, using a FileStreamDecoder
    ///
    /// - Note: The request is started in this function.
    ///
    /// - Parameters:
    ///   - streamDecoder: StreamDecoder object
    ///   - request: request to use
    ///   - destination: destination local file url
    ///   - progressValue: progress percentage (from 0 to 100)
    ///   - completion: completion callback
    ///   - result: the request result
    ///   - localFileUrl: the local file url of the downloaded file. Note that when the completion closure exits, this
    ///                   local file will deleted.
    /// - Returns: the request
    public func downloadFile(
        streamDecoder: StreamDecoder, request: URLRequest, destination: URL,
        completion: @escaping (_ result: Result, _ localFileUrl: URL?) -> Void) -> CancelableCore {

        var request = request
        request.httpMethod = "GET"

        var task: URLSessionTask!
        task = session.dataTask(with: request)

        streamDlCompletionCbs[task.taskIdentifier] = DownloadCompletionCb(
            destination: destination, callback: completion)
        streamWriters[task.taskIdentifier] = StreamWriter(withFileUrl: destination, streamDecoder: streamDecoder)
        task.resume()

        return task
    }

    /// Request a delete
    ///
    /// - Parameters:
    ///   - request: request to use
    ///   - completion: completion callback
    ///   - result: the request result
    /// - Returns: the request
    public func delete(
        request: URLRequest, completion: @escaping (_ result: Result) -> Void) -> CancelableCore {

        var request = request
        request.httpMethod = "DELETE"

        var task: URLSessionTask!
        task = session.dataTask(with: request) { _, response, error in

            let result: Result
            if let error = error {
                if error as NSError == HttpSessionCore.canceledError {
                    result = .canceled
                } else {
                    result = .error(error)
                }
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    result = .success(response.statusCode)
                } else {
                    result = .httpError(response.statusCode)
                }
            } else {
                result = HttpSessionCore.defaultError
            }

            // as we are in the delegateQueue, executes the call back in main thread
            DispatchQueue.main.async {
                ULog.d(.httpClientTag, "Task \(task.taskIdentifier) (\(request.url?.description ?? "")) " +
                    "did complete with result: \(result)")
                completion(result)
            }
        }
        task.resume()

        return task
    }
}

/// Extension of HttpSessionCore that implements all kind of URLSession delegates
extension HttpSessionCore: URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // check if the task is a streamDownload task
        if let streamWriter = streamWriters[dataTask.taskIdentifier] {
            do {
                try streamWriter.processData(data)
            } catch {
                // Error. Stop this task
                dataTask.cancel()
                // as we are in the delegateQueue, executes the call back in main thread
                DispatchQueue.main.async {
                    ULog.e(.httpClientTag, "streamWriter \(error.localizedDescription)")
                    let streamDownloadCb = self.streamDlCompletionCbs[dataTask.taskIdentifier]
                    self.streamDlCompletionCbs[dataTask.taskIdentifier] = nil
                    self.streamWriters[dataTask.taskIdentifier]  = nil
                    if streamDownloadCb != nil {
                        streamDownloadCb!.callback(Result.error(error), nil)
                    }
                }
            }
        }
    }

    public func urlSession(
        _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64) {

        guard let progressCb = progressCbs[task.taskIdentifier] else {
            ULog.e(.httpClientTag, "Progress callback not found for task \(task.taskIdentifier)")
            return
        }
        let progress = Int((Double(totalBytesSent) / Double(totalBytesExpectedToSend)) * 100)

        // as we are in the delegateQueue, executes the call back in main thread
        DispatchQueue.main.async {
            ULog.d(.httpClientTag, "Upload progress of task: \(progress)")
            progressCb(progress)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // this function is only called when no completion closure is directly passed to the task, that happens
        // on download tasks or for streamDownload Tasks

        // if error is nil AND if the task is a `downloadTask', the result has already been handled by
        // `urlSession(:downloadTask:didFinishDownloadingTo:)`
        if error == nil && dlCompletionCbs[task.taskIdentifier] != nil {
            return
        }

        var result: Result
        if let error = error {
            // as the documentation states:
            // "Unlike URLSessionDataTask or URLSessionUploadTask, NSURLSessionDownloadTask reports server-side errors
            // reported through HTTP status codes into corresponding NSError objects"
            switch (error as NSError).code {
            case NSURLErrorUserAuthenticationRequired:
                result = .httpError(401)
            case NSURLErrorNoPermissionsToReadFile:
                result = .httpError(403)
            case NSURLErrorUserAuthenticationRequired:
                result = .httpError(407)
            case NSURLErrorFileDoesNotExist:
                // `NSURLErrorFileDoesNotExist` is used as a default error code for an http error.
                // We use the HTTP error code 418 to express this unknown default error.
                // 418 error code is "I'm a teapot" error (which is the best error name ever).
                result = .httpError(418)
            default:
                if error as NSError == HttpSessionCore.canceledError {
                    result = .canceled
                } else {
                    result = .error(error)
                }
            }
        } else {
            result = .success(200)
        }

        // as we are in the delegateQueue, executes the call back in main thread
        DispatchQueue.main.async {
            ULog.d(.httpClientTag, "Task \(task.taskIdentifier) (\(task.currentRequest?.url?.description ?? "")) " +
                "did complete with result: \(result)")

            if let downloadCb = self.dlCompletionCbs[task.taskIdentifier] {
                // The task is a "downloadTask"
                self.progressCbs[task.taskIdentifier] = nil
                self.dlCompletionCbs[task.taskIdentifier] = nil
                downloadCb.callback(result, nil)
            } else if let streamDownloadCb = self.streamDlCompletionCbs[task.taskIdentifier] {
                // The task is a "Stream downloadTask"
                var resultUrl: URL?
                if let streamWriter = self.streamWriters[task.taskIdentifier] {
                    do {
                        // finalize the file
                        try streamWriter.processData(nil)
                        resultUrl = streamWriter.resultUrl
                    } catch let errorWriter {
                        ULog.e(.httpClientTag, "streamWriter \(errorWriter.localizedDescription)")
                        if error == nil {
                            // we use the urlsession error, but if this one is nil we use the StreamWriterError
                            result = .error(errorWriter)
                        }
                    }
                }
                self.streamDlCompletionCbs[task.taskIdentifier] = nil
                self.streamWriters[task.taskIdentifier] = nil
                streamDownloadCb.callback(result, resultUrl)
            } else {
                ULog.e(.httpClientTag, "Completion callback not found for task \(task.taskIdentifier)")
            }
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            ULog.d(.httpClientTag, "UrlSessionDidFinishEvents forBackgroundURLSession \(session)")
            GroundSdk.backgroundTaskCompletionHandlers.values.forEach { $0() }
        }
    }
}

extension HttpSessionCore: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        guard let completionCb = dlCompletionCbs[downloadTask.taskIdentifier] else {
            ULog.e(.httpClientTag, "Completion callback not found for task \(downloadTask.taskIdentifier)")
            return
        }

        let result: Result
        if let response = downloadTask.response as? HTTPURLResponse {
            if response.statusCode == 200 {
                result = .success(response.statusCode)
            } else {
                result = .httpError(response.statusCode)
            }
        } else {
            result = .httpError(403)
        }

        var localFileUrlUsed: URL?

        if case .success = result {
            let localFileUrl = completionCb.destination
            do {
                try FileManager.default.createDirectory(
                    at: localFileUrl.deletingLastPathComponent(), withIntermediateDirectories: true,
                    attributes: nil)
                try FileManager.default.moveItem(at: location, to: localFileUrl)
                localFileUrlUsed = localFileUrl
            } catch let error {
                ULog.w(.httpClientTag, "Failed to move file at \(localFileUrl): " +
                    error.localizedDescription)
            }
        }
        // as we are in the delegateQueue, executes the call back in main thread
        DispatchQueue.main.async {
            self.progressCbs[downloadTask.taskIdentifier] = nil
            self.dlCompletionCbs[downloadTask.taskIdentifier] = nil

            ULog.d(.httpClientTag, "Task \(downloadTask.taskIdentifier) " +
                "(\(downloadTask.currentRequest?.url?.description ?? "")) did complete with result: \(result)")
            completionCb.callback(result, localFileUrlUsed)
        }
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

        guard let progressCb = progressCbs[downloadTask.taskIdentifier] else {
            ULog.e(.httpClientTag, "Progress callback not found for task \(downloadTask.taskIdentifier)")
            return
        }

        let progress = Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100)
        // as we are in the delegateQueue, executes the call back in main thread
        DispatchQueue.main.async {
            progressCb(progress)
        }
    }

}

/// Extension of URLSessionTask that declare that this object implements the CancelableCore protocol
extension URLSessionTask: CancelableCore { }
