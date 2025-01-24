#!/usr/bin/env swift

import Foundation

let fileManager = FileManager.default
let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let imagesDirectoryURL = currentDirectoryURL.appendingPathComponent("images/v2")
let outputFileURL = currentDirectoryURL.appendingPathComponent("output.csv")

let ocrScriptPath = currentDirectoryURL.appendingPathComponent("ocr.swift").path

func runOCROnImage(at imagePath: String) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = [ocrScriptPath, imagePath]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe // エラー出力もパイプにリダイレクト

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "不明なエラー"
        throw NSError(domain: "OCRスクリプト", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "OCRスクリプト実行エラー: \(errorMessage)"])
    }

    return pipe.fileHandleForReading.readDataToEndOfFile()
}

func processImageFiles() throws {
    let fileURLs = try fileManager.contentsOfDirectory(at: imagesDirectoryURL, includingPropertiesForKeys: nil)
        .filter { ["PNG", "JPG", "JPEG"].contains($0.pathExtension.uppercased()) }

    var csvLines: [String] = ["曲名,Lv,creation_date"] // CSVヘッダー

    for fileURL in fileURLs {
        let imagePath = fileURL.path
        print("Processing image: \(imagePath)")

        let imageData = try runOCROnImage(at: imagePath)
        guard let jsonString = String(data: imageData, encoding: String.Encoding.utf8),
              let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            print("JSONデータの変換に失敗: \(imagePath)")
            continue
        }

        do {
            if let jsonResult = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
               let recognize_text = jsonResult["recognize_text"] as? [[String: Any]],
               let creation_date = jsonResult["creation_date"] as? String {

                var songName: String? = nil
                var level: String? = nil
                var csvLine: String = "" // csvLine をここで宣言

                for result in recognize_text {
                    if let text = result["text"] as? String {
                        if songName == nil {
                            songName = text
                        } else if text.contains("楽曲LV.") {
                            let parts = text.components(separatedBy: ".")
                            if parts.count == 2 {
                                level = parts[1]
                            }
                        }
                    }
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm" // ocr.swift の creation_date のフォーマットに合わせる
                if let date = dateFormatter.date(from: creation_date) {
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // CSV 出力用に秒まで出力
                    let creationDateString = dateFormatter.string(from: date)
                    csvLine = "\(songName ?? ""),\(level ?? ""),\(creationDateString)"
                } else {
                    csvLine = "\(songName ?? ""),\(level ?? ""),\(creation_date)" // creation_date のパースに失敗した場合、そのまま出力
                }

                csvLines.append(csvLine)
                print("CSV line: \(csvLine)")
            }
        } catch {
            print("JSON解析エラー: \(imagePath) - \(error)")
        }
    }

    let csvString = csvLines.joined(separator: "\n")
    do {
        try csvString.write(to: outputFileURL, atomically: true, encoding: .utf8)
        print("CSVファイル出力完了: \(outputFileURL.path)")
    } catch {
        print("CSVファイル出力エラー: \(outputFileURL.path) - \(error)")
    }
}

do {
    try processImageFiles()
} catch {
    print("エラー: \(error)")
}
