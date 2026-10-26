import Foundation

public enum WebNavigationFailure {
    /// WebKit reports policy-cancelled navigations as legacy error 102, including
    /// optional app-deep-link probes during web sign-in. The visible page is valid.
    public static func isCancellation(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return true }
        return ["WKErrorDomain", "WebKitErrorDomain"].contains(error.domain) && error.code == 102
    }
}
