//
//  DataProcessor.swift
//  411 Project
//
//  Created by Larry on 9/1/26.
//

import Foundation
// Consider importing NaturalLanguage for other language cards?
// For now, just work with English

struct SetManifestItem: Codable, Identifiable {
    let id: String
    let name: String
    let printedTotal: Int
    let total: Int
    let releaseDate: String
}

struct CardImage: Codable, Equatable {
    let small: String
    let large: String?
}

struct PokemonCard: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let number: String
    let images: CardImage
    let availableVariants: [String]? // e.g. ["normal", "reverseHolofoil"]
    
    // Helper to map API strings to your CardVariant enum
    var mappedVariants: [CardVariant] {
        guard let availableVariants, !availableVariants.isEmpty else {
            return [.normal] // fallback
        }
        return availableVariants.compactMap { variantString in
            switch variantString {
            case "normal": return .normal
            case "holofoil": return .holo
            case "reverseHolofoil": return .reverseHolo
            case "1stEditionHolofoil": return .firstEdition
            default: return nil
            }
        }
    }
}


struct cardNumberProcessor {
    // MARK: - 1. Unified Card Number Extraction

    /// Extracts collector number and set total from anywhere in the scanned text.
    func readCardNumber(from fullText: String) -> (number: String?, denominator: String?) {
        var text = fullText
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "|", with: "/")
            .replacingOccurrences(of: "!", with: "/")
            .replacingOccurrences(of: "I", with: "/")
        
        // Standard fraction format: "081/198", "TG01/TG30", "25 / 102"
        let fractionRegex = /([A-Za-z]{0,3}\d{1,4})\s*\/\s*([A-Za-z]{0,3}\d{2,4})/
        if let match = text.firstMatch(of: fractionRegex) {
            let num = String(match.1).trimmingCharacters(in: .whitespaces)
            let denom = String(match.2).trimmingCharacters(in: .whitespaces)
            return (num, denom)
        }
        
        // Spaced format fallback (e.g. "081 198")
        let spacedRegex = /\b(\d{2,3})\s+(\d{3})\b/
        if let match = text.firstMatch(of: spacedRegex) {
            let num = String(match.1)
            let denom = String(match.2)
            return (num, denom)
        }
        
        // Promo format fallback (e.g. "SVP 025", "SWSH123")
        let promoRegex = /(?i)\b(SVP|SWSH|SM|XY)?\s*(\d{3,4})\b/
        if let match = text.firstMatch(of: promoRegex) {
            let prefix = match.1.map(String.init) ?? ""
            let number = String(match.2)
            return (prefix.isEmpty ? number : "\(prefix)\(number)", nil)
        }
        
        return (nil, nil)
    }

    // MARK: - 2. Text Cleaning & Token Scoring

    func cleanTextForMatching(_ rawText: String) -> String {
        let replaced = rawText.replacingOccurrences(of: "\n", with: " ")
        let allowedChars = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = String(replaced.unicodeScalars.filter { allowedChars.contains($0) })
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Checks if candidate card name tokens exist anywhere inside the OCR text block.
    func scoreCardNameInText(cardName: String, scannedText: String) -> Double {
        let cleanScanned = cleanTextForMatching(scannedText)
        let cleanTarget = cleanTextForMatching(cardName)
        
        guard !cleanScanned.isEmpty, !cleanTarget.isEmpty else { return 0.0 }
        
        // Exact substring match (e.g., "miraidon ex" appears verbatim in the text)
        if cleanScanned.contains(cleanTarget) {
            return 1.0
        }
        
        // Token-based matching for multi-word cards (e.g. "Professor's Research", "Pikachu ex")
        let targetTokens = cleanTarget.components(separatedBy: " ").filter { !$0.isEmpty }
        guard !targetTokens.isEmpty else { return 0.0 }
        
        let scannedTokens = Set(cleanScanned.components(separatedBy: " ").filter { !$0.isEmpty })
        let matchedCount = targetTokens.filter { scannedTokens.contains($0) }.count
        
        return Double(matchedCount) / Double(targetTokens.count)
    }

    // MARK: - 3. Unified Identification Pipeline

    func takeTextAndFindCard(fullText: String) async -> [PokemonCard] {
        print("\n--- [Card Identification Pipeline] ---")
        print("🔍 Full Unified OCR Text:\n\"\(fullText)\"")
        
        // 1. Extract numerator and denominator from full text
        let (rawNumOpt, rawDenomOpt) = readCardNumber(from: fullText)
        let rawNum = (rawNumOpt ?? "").trimmingCharacters(in: .whitespaces)
        let rawDenom = (rawDenomOpt ?? "").trimmingCharacters(in: .whitespaces)
        
        let cleanNum = rawNum.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        let cleanDenom = rawDenom.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        
        print("🔢 Extracted: Number = '\(rawNum)' (norm: '\(cleanNum)'), Denominator = '\(rawDenom)' (norm: '\(cleanDenom)')")
        
        // 2. Fetch Manifest
        guard let manifest = try? await PokemonAPIService.shared.fetchSetsManifest() else {
            print("❌ Pipeline Error: Could not load sets manifest.")
            return []
        }
        
        // 3. Find candidate sets matching denominator
        var candidateSets = manifest.filter {
            let printed = String($0.printedTotal)
            let total = String($0.total)
            return printed == rawDenom || total == rawDenom || printed == cleanDenom || total == cleanDenom
        }
        
        print("📦 Candidate Sets Matching Denominator (\(rawDenom)): [\(candidateSets.map { "\($0.id) (\($0.name))" }.joined(separator: ", "))]")
        
        // Fallback if no denominator matched: check modern sets
        if candidateSets.isEmpty {
            print("⚠️ No sets matched denominator '\(rawDenom)'. Searching recent SV sets.")
            candidateSets = manifest.filter { $0.id.hasPrefix("sv") }
        }
        
        var rankedCards: [(card: PokemonCard, score: Double)] = []
        
        // 4. Score cards across candidate sets
        for setItem in candidateSets {
            guard let cards = try? await PokemonAPIService.shared.fetchCards(for: setItem.id) else {
                continue
            }
            
            for card in cards {
                var score = 0.0
                let cardNormNum = card.number.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
                
                let numberMatches = (!rawNum.isEmpty && (card.number == rawNum || cardNormNum == cleanNum))
                let nameScore = scoreCardNameInText(cardName: card.name, scannedText: fullText)
                
                if numberMatches {
                    score += 0.6
                    print("   Found Number Match: [\(setItem.id)] #\(card.number) \(card.name) (Name Score: \(String(format: "%.2f", nameScore)))")
                }
                
                if nameScore > 0.4 {
                    score += (nameScore * 0.4)
                }
                
                if score > 0.5 {
                    rankedCards.append((card: card, score: score))
                }
            }
        }
        
        rankedCards.sort { $0.score > $1.score }
        
        if let best = rankedCards.first {
            print("✅ Best Match: \(best.card.name) [\(best.card.id)] (Score: \(String(format: "%.2f", best.score)))")
            
        } else {
            print("❌ No matching card found.")
        }
        print("--------------------------------------\n")
        
        return rankedCards.map { $0.card }
    }
}
