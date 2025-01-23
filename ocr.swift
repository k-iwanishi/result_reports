#!/usr/bin/swift

import Foundation
#if os(macOS)
import AppKit
import Vision

func getImageCreationDate(from imagePath: String) -> Date? {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: imagePath) {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: imagePath)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    } else {
        return nil
    }
}

func recognizeText(from imagePath: String) -> [String: Any]? {
    guard let image = NSImage(contentsOfFile: imagePath) else {
        return ["error": "Could not load image from path: \(imagePath)"]
    }
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return ["error": "Could not get CGImage from NSImage"]
    }

    let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
    var jsonObjectResult: [String: Any]? = nil // JSONオブジェクトを格納する変数

    let request = VNRecognizeTextRequest { request, error in
        if let error = error {
            jsonObjectResult = ["error": "Text recognition error: \(error)"]
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            jsonObjectResult = ["error": "No text observations found"]
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

        jsonObjectResult = ["results": results]
    }

    do {
        request.recognitionLanguages = ["ja-JP", "en-US"]
        try requestHandler.perform([request])
        return jsonObjectResult // JSONオブジェクトを返す
    } catch {
        return ["error": "テキスト認識リクエストの実行エラー: \(error)"]
    }
}

if CommandLine.arguments.count != 2 {
    print("Usage: ocr.swift <image_path>")
} else {
    let imagePath = CommandLine.arguments[1]
    var output: [String: Any] = [:]
    if let jsonObjectResult = recognizeText(from: imagePath) {
        output["recognize_text"] = jsonObjectResult["results"]
    } else {
        output["recognize_text"] = ["error": "テキスト認識処理でエラーが発生しました。"]
    }
    if let creationDate = getImageCreationDate(from: imagePath) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: creationDate)
        output["creation_date"] = dateString
    } else {
        output["creation_date"] = "画像の作成日を取得できませんでした。"
    }
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    } catch {
        print("JSONエンコードエラー: \(error)")
    }
}

#else
print("Error: This script is only supported on macOS because it uses the Vision framework.")
#endif
