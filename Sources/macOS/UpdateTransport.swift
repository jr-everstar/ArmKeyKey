import Foundation
import CryptoKit

// Restrict redirects as well as the original URL; no cookies, accounts or analytics.
final class UpdateRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let package: Bool
    init(package: Bool) { self.package = package }
    static func allowed(_ url: URL, package: Bool) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.port == nil else { return false }
        if !package { return url == UpdateFeed.endpoint }
        if UpdateFeed.validPackageURL(url) { return true }
        return ["release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(url.host ?? "")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map { Self.allowed($0, package: package) } == true ? request : nil)
    }
}

enum UpdateTransport {
    static func session(package: Bool) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = package ? 1800 : 60
        return URLSession(configuration: configuration, delegate: UpdateRedirects(package: package), delegateQueue: nil)
    }
    static func feed(using supplied: URLSession? = nil) async throws -> UpdateFeed {
        try Task.checkCancellation()
        let session = supplied ?? session(package: false)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: URLRequest(url: UpdateFeed.endpoint, cachePolicy: .reloadIgnoringLocalCacheData))
        guard (response as? HTTPURLResponse)?.statusCode == 200, response.url == UpdateFeed.endpoint,
              response.expectedContentLength <= 1024 * 1024 else { throw UpdateFailure.invalidFeed }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
            guard data.count <= 1024 * 1024 else { throw UpdateFailure.invalidFeed }
        }
        return try UpdateFeed.decode(data)
    }
    static func download(_ release: UpdateRelease, to destination: URL,
                         using supplied: URLSession? = nil, progress: @escaping @Sendable (Double) -> Void) async throws {
        try Task.checkCancellation()
        guard UpdateFeed.validPackageURL(release.package.url) else { throw UpdateFailure.download }
        let session = supplied ?? session(package: true)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(from: release.package.url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              response.url.map({ UpdateRedirects.allowed($0, package: true) }) == true,
              response.expectedContentLength == -1 || response.expectedContentLength == release.package.size
        else { throw UpdateFailure.download }
        FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let file = try FileHandle(forWritingTo: destination)
        defer { try? file.close() }
        var buffer = Data(), count: Int64 = 0
        var checksum = SHA256()
        for try await byte in bytes {
            try Task.checkCancellation()
            count += 1
            guard count <= release.package.size else { throw UpdateFailure.download }
            buffer.append(byte)
            if buffer.count == 65536 {
                try file.write(contentsOf: buffer); checksum.update(data: buffer); buffer.removeAll(keepingCapacity: true)
                progress(Double(count) / Double(release.package.size))
            }
        }
        try Task.checkCancellation()
        try file.write(contentsOf: buffer); checksum.update(data: buffer)
        guard count == release.package.size,
              checksum.finalize().map({ String(format: "%02x", $0) }).joined() == release.package.sha256
        else { throw UpdateFailure.verification }
        progress(1)
    }
}
