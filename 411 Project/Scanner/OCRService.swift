import Foundation
import Vision
import CoreImage
import UIKit

// 1. Data model to hold the text and its position on the card
struct RecognizedBlock {
    let text: String
    let boundingBox: CGRect // Normalized: (0.0, 0.0) is bottom-left, (1.0, 1.0) is top-right
}

class OCRService {
    // Callback closure that sends extracted text back to ContentView
    var onTextExtracted: ((_ topText: String, _ bottomText: String) -> Void)?
    
    // 2. The missing async function called by CameraManager
    func extractText(from image: UIImage) async -> [RecognizedBlock] {
        guard let cgImage = image.cgImage else { return [] }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let blocks = observations.compactMap { observation -> RecognizedBlock? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedBlock(
                        text: topCandidate.string,
                        boundingBox: observation.boundingBox
                    )
                }
                
                continuation.resume(returning: blocks)
            }
            
            // Text recognition settings for card scans
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false // Preserves card numbers and stylized names
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Vision text extraction failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    /// Runs OCR on regions of interest (ROI)
    func processCardImage(_ ciImage: CIImage) {
        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                return
            }
            
            var topStrings: [String] = []
            var bottomStrings: [String] = []
            
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first?.string else { continue }
                
                // Vision bounding boxes have normalized coordinates (0.0 to 1.0) with origin at bottom-left
                let boundingBox = observation.boundingBox
                
                // Top region (card title area: upper 25% of the card)
                if boundingBox.origin.y > 0.75 {
                    topStrings.append(candidate)
                }
                
                // Bottom region (set info & card number: lower 15% of the card)
                if boundingBox.origin.y < 0.15 {
                    bottomStrings.append(candidate)
                }
            }
            
            let combinedTop = topStrings.joined(separator: " ")
            let combinedBottom = bottomStrings.joined(separator: " ")
            
            // Only trigger if we found text in at least one area
            if !combinedTop.isEmpty || !combinedBottom.isEmpty {
                DispatchQueue.main.async {
                    self?.onTextExtracted?(combinedTop, combinedBottom)
                }
            }
        }

        // Recognition settings
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // Better for reading numbers and stylized names

        do {
            try requestHandler.perform([request])
        } catch {
            print("Vision OCR failed: \(error)")
        }
    }
}
