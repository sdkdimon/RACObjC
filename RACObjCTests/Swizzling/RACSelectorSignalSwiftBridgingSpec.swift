import Quick
import Nimble

final class RACSelectorSignalSwiftBridgingSpec: QuickSpec {
	override class func spec() {
		describe("RACSelectorSignalError") {
			it("bridges RACSelectorSignalErrorMethodSwizzlingRace to a Swift error code") {
				let error: Error = NSError(domain: RACSelectorSignalErrorDomain, code: 1)
				expect(RACSelectorSignalError.methodSwizzlingRace ~= error).to(beTrue())
			}
		}
	}
}
