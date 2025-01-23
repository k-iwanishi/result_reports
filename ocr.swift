#!/usr/bin/swift

import Foundation
#if os(macOS)
import AppKit
import Vision

func getImageCreationDate(from imagePath: String) {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: imagePath) {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: imagePath)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ja_JP")
                formatter.dateFormat = "yyyy年M月d日 H時m分s秒"
                let dateString = formatter.string(from: creationDate)
                print("画像の作成日: \(dateString)")
            } else {
                print("画像の作成日を取得できませんでした。")
            }
        } catch {
            print("エラー: \(error)")
        }
    } else {
        print("ファイルが存在しません: \(imagePath)")
    }
}

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

            var label: String? = nil
            if boundingBox.origin.x > 0.19 && boundingBox.origin.x < 0.20 && boundingBox.origin.y > 0.94 && boundingBox.origin.y < 0.95 {
                label = "曲名"
            } else if boundingBox.origin.x > 0.30 && boundingBox.origin.x < 0.31 && boundingBox.origin.y > 0.89 && boundingBox.origin.y < 0.90 {
                label = "Lv"
            }

            var result: [String: Any] = [
                "text": text,
                "boundingBox": [
                    "x": boundingBox.origin.x,
                    "y": boundingBox.origin.y,
                    "width": boundingBox.width,
                    "height": boundingBox.height
                ]
            ]
            if let label = label {
                result["label"] = label
            }
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
    getImageCreationDate(from: imagePath) // 作成日出力メソッドを追加
}

#else
print("Error: This script is only supported on macOS because it uses the Vision framework.")
#endif
