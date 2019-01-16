import XCTest
@testable import WordPressKit

final class SiteCreationSegmentsTests: RemoteTestCase, RESTTestable {

    func testSiteSegmentsRequest_Succeeds() {
        // Given
        let endpoint = "segments"
        let fileName = "site-segments-multiple.json"
        stubRemoteResponse(endpoint, filename: fileName, contentType: .ApplicationJSON)

        let expectedSegmentsCount = 5
        let request = SiteSegmentsRequest(locale: "es_ES")

        // When, Then
        let segmentsExpectation = expectation(description: "Initiate site segments request")
        let remote = WordPressComServiceRemote(wordPressComRestApi: getRestApi())
        remote.retrieveSegments(request: request) { result in
            segmentsExpectation.fulfill()
            switch result {
            case .success(let segments):
                XCTAssertNotNil(segments)

                let mobileSegmentsCount = segments.count
                XCTAssertEqual(mobileSegmentsCount, expectedSegmentsCount)

            case .failure(_):
                XCTFail()
            }
        }

        waitForExpectations(timeout: timeout)
    }

}
