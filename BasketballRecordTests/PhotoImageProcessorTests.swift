import UIKit
import XCTest
@testable import BasketballRecord

@MainActor
final class PhotoImageProcessorTests: XCTestCase {
    func testProcessingDownsamplesLargeImageToMaximumDimension() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1440, height: 720)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1440, height: 720))
        }
        let input = try XCTUnwrap(image.pngData())

        let output = try await PhotoImageProcessor.process(input)

        let processedImage = try XCTUnwrap(UIImage(data: output))
        XCTAssertLessThanOrEqual(processedImage.size.width, 720)
        XCTAssertEqual(processedImage.size.height, 360, accuracy: 1)
    }

    func testProcessingPreservesUnrecognizedImageData() async throws {
        let input = Data([0x01, 0x02, 0x03])

        let output = try await PhotoImageProcessor.process(input)

        XCTAssertEqual(output, input)
    }
}
