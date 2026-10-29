// macOS Vision adapter; these results do not establish iPad Vision accuracy.
// swift tools/ocr_vision.swift /path/to/manifest.json > predictions.json
import Foundation
import Vision

struct Sample: Decodable { let id: String; let image: String }
struct Manifest: Decodable { let samples: [Sample] }
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift tools/ocr_vision.swift manifest.json\n", stderr)
    exit(2)
}
let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
var output: [String: String] = [:]
for sample in manifest.samples {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false
    request.customWords = ["??", "？？"]
    request.minimumTextHeight = 0.005
    let imageURL = manifestURL.deletingLastPathComponent().appendingPathComponent(sample.image)
    try VNImageRequestHandler(url: imageURL).perform([request])
    output[sample.id] = (request.results ?? []).sorted {
        abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.025
            ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
    }.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
