import Quick
import Nimble

final class RACCommandSwiftBridgingSpec: QuickSpec {
	override class func spec() {
		describe("RACCommandError") {
			it("bridges RACCommandErrorNotEnabled to a Swift error code") {
				let error: Error = NSError(domain: RACCommandErrorDomain, code: 1)
				expect(RACCommandError.notEnabled ~= error).to(beTrue())
			}
		}
	}
}
