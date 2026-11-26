import Foundation
import Photos

extension TimeInterval {
    /// "0:42", "12:05" or "1:02:03".
    var clockString: String {
        let total = Swift.max(0, Int(self.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Int {
    /// "1 photo", "3 photos".
    func counted(_ singular: String, _ plural: String? = nil) -> String {
        "\(self.formatted()) \(self == 1 ? singular : (plural ?? singular + "s"))"
    }
}

extension PHAsset {
    var accessibilityDescription: String {
        let kind = mediaType == .video ? "Video" : "Photo"
        guard let creationDate else { return kind }
        let date = creationDate.formatted(date: .long, time: .shortened)
        return "\(kind), \(date)"
    }
}
