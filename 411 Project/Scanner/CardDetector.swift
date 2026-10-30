//
//  CardDetector.swift
//  411 Project
//
//  Created by Larry on 9/1/26.
//


import UIKit
import Vision
import CoreImage

struct CardDetector {
    private let context = CIContext()
    
    func extractAndFlattenCard(from image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 1. Detect the card rectangle
        guard let observation = await detectCardRectangle(in: cgImage) else { return nil }
        
        // 2. Un-skew using Core Image
        return unskewCard(cgImage: cgImage, observation: observation)
    }
    
    private func detectCardRectangle(in cgImage: CGImage) async -> VNRectangleObservation? {
        await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, _ in
                guard let results = request.results as? [VNRectangleObservation],
                      let topCard = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: topCard)
            }
            
            // Playing card parameters (~2.5 x 3.5 ratio = ~0.71 aspect ratio)
            request.minimumAspectRatio = 0.5
            request.maximumAspectRatio = 0.9
            request.minimumConfidence = 0.6
            request.maximumObservations = 1
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func unskewCard(cgImage: CGImage, observation: VNRectangleObservation) -> UIImage? {
        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = ciImage.extent.size
        
        // Convert normalized Vision coordinates (0.0 - 1.0) to raw pixel coordinates
        let topLeft = CGPoint(x: observation.topLeft.x * imageSize.width, y: observation.topLeft.y * imageSize.height)
        let topRight = CGPoint(x: observation.topRight.x * imageSize.width, y: observation.topRight.y * imageSize.height)
        let bottomLeft = CGPoint(x: observation.bottomLeft.x * imageSize.width, y: observation.bottomLeft.y * imageSize.height)
        let bottomRight = CGPoint(x: observation.bottomRight.x * imageSize.width, y: observation.bottomRight.y * imageSize.height)
        
        // Apply CIPerspectiveCorrection filter
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        guard let outputCIImage = filter.outputImage,
              let outputCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
}
