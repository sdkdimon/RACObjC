import Quick
import Nimble

final class RACSignalSwiftBridgingSpec: QuickSpec {
	override class func spec() {
		describe("RACSignalError") {
			it("bridges RACSignalErrorTimedOut to a Swift error code") {
				let error: Error = NSError(domain: RACSignalErrorDomain, code: 1)
				expect(RACSignalError.timedOut ~= error).to(beTrue())
			}

			it("bridges RACSignalErrorNoMatchingCase to a Swift error code") {
				let error: Error = NSError(domain: RACSignalErrorDomain, code: 2)
				expect(RACSignalError.noMatchingCase ~= error).to(beTrue())
			}
		}
	}
}
