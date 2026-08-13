import XCTest
@testable import record_catch

final class CatchRecordSubmissionServiceTests: XCTestCase {

    func test_stubService_submit_succeeds() async throws {
        let sut = StubCatchRecordSubmissionService()

        try await sut.submit(referenceNumber: "A1234520260727150815")
        // No throw = success; nothing further to assert against this in-memory stub.
    }
}
