import AVFoundation
import Vision
import SwiftUI

@Observable
class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    var recognizedText: String = "Press 'Scan Card' or import a file."
    var croppedCard: UIImage? = nil
    var isProcessing: Bool = false
    
    // NEW: Expose match and price state directly to SwiftUI
    var identifiedCard: PokemonCard? = nil
    var cardPrice: Double? = nil
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let cardDetector = CardDetector()
    private let ocrService = OCRService()
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
    }
    
    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }
    
    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    func captureAndProcessCard() {
        guard !isProcessing else { return }
        isProcessing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let fullImage = UIImage(data: data) else {
            Task { @MainActor in self.isProcessing = false }
            return
        }
        
        processImageWithFallback(fullImage)
    }
    
    func processCustomImage(_ image: UIImage) {
        guard !isProcessing else { return }
        isProcessing = true
        processImageWithFallback(image)
    }
    
    
    // Unified Pipeline with Shape Detection Fallback
    private func processImageWithFallback(_ inputImage: UIImage) {
        Task {
            // Attempt shape detection / un-skew
            let flattenedCard: UIImage? = await cardDetector.extractAndFlattenCard(from: inputImage)
            let imageToScan: UIImage = flattenedCard ?? inputImage
            
            // Extract all text blocks into one single string
            let blocks = await ocrService.extractText(from: imageToScan)
            let fullText: String = blocks.map { $0.text }.joined(separator: "\n")
            
            // Run unified identification
            let processor = cardNumberProcessor() // Ensure type casing matches your struct/class
            let matches = await processor.takeTextAndFindCard(fullText: fullText)
            let match = matches.first
            
            // Fetch live price if a match was identified
            var fetchedPrice: Double? = nil
            if let card = match {
                let setCode = card.id.components(separatedBy: "-").first ?? ""
                let prices: [String: [String: Double]]? = try? await PokemonAPIService.shared.fetchPrices(for: setCode)
                
                // Look up the card's variant map, then grab the primary price (e.g. normal, holo, or the first available)
                if let cardVariants = prices?[card.number] {
                    fetchedPrice = cardVariants["normal"] ?? cardVariants["holofoil"] ?? cardVariants.values.first
                }
            }
            
            await MainActor.run {
                self.croppedCard = flattenedCard
                self.identifiedCard = match
                self.cardPrice = fetchedPrice
                
                if fullText.isEmpty {
                    self.recognizedText = flattenedCard != nil
                    ? "Card detected, but no text found."
                    : "No card shape detected and no readable text found."
                } else {
                    self.recognizedText = fullText
                }
                
                self.isProcessing = false
            }
        }
    }
}
