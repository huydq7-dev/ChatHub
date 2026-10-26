import Foundation
import Testing

@testable import ChatHubCore

struct WebNavigationFailureTests {
    @Test(arguments: ["WebKitErrorDomain", "WKErrorDomain"])
    func policyCancellationsNeverHideTheSignInPage(_ domain: String) {
        #expect(WebNavigationFailure.isCancellation(NSError(domain: domain, code: 102)))
    }

    @Test func supersededRequestsAreNotFailures() {
        #expect(WebNavigationFailure.isCancellation(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
    }

    @Test(arguments: [NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorServerCertificateUntrusted])
    func realNetworkAndSecurityErrorsStayVisible(_ code: Int) {
        #expect(!WebNavigationFailure.isCancellation(NSError(domain: NSURLErrorDomain, code: code)))
    }

    @Test func unrelatedErrorsAreNotSwallowed() {
        #expect(!WebNavigationFailure.isCancellation(NSError(domain: NSCocoaErrorDomain, code: 102)))
    }
}
