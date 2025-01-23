import CoreGraphics
import Quartz
import Vision

let target = CommandLine.arguments[1]

guard let image = NSImage(contentsOf: URL(filePath: target)) else { exit(0) }

let request = VNRecognizeTextRequest { (request, _) in
    let observations = request.results as? [VNRecognizedTextObservation] ?? []
    let obs = observations.map { $0.topCandidates(1).first?.string ?? ""}
    let result = obs.joined(separator: "\n")
    print(result)
}

request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = ["ja", "en"]

guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(0) }

try! VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
