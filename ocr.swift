#!/usr/bin/swift

import Foundation
#if os(macOS)
import AppKit
import Vision

func recognizeText(from imagePath: String) {
    guard let image = NSImage(contentsOfFile: imagePath) else {
        print("Error: Could not load image from path: \(imagePath)")
        return
    }
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Error: Could not get CGImage from NSImage")
        return
    }

    let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
    let request = VNRecognizeTextRequest { request, error in
        if let error = error {
            print("Error: \(error)")
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("No text observations found")
            return
        }

        var results: [[String: Any]] = []
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let text = topCandidate.string
            let boundingBox = observation.boundingBox

            let result = [
                "text": text,
                "boundingBox": [
                    "x": boundingBox.origin.x,
                    "y": boundingBox.origin.y,
                    "width": boundingBox.width,
                    "height": boundingBox.height
                ]
            ] as [String : Any]
            results.append(result)
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("Error encoding JSON: \(error)")
        }
    }

    do {
        request.recognitionLanguages = ["ja-JP", "en-US"]
        try requestHandler.perform([request])
    } catch {
        print("Error performing text recognition request: \(error)")
    }
}

if CommandLine.arguments.count != 2 {
    print("Usage: ocr.swift <image_path>")
} else {
    let imagePath = CommandLine.arguments[1]
    recognizeText(from: imagePath)
}

#else
print("Error: This script is only supported on macOS because it uses the Vision framework.")
#endif
