import Foundation

extension Date {
    var sessionTitle: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: self)
    }

    var shortDisplay: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f.string(from: self)
    }

    var relativeDisplay: String {
        let rf = RelativeDateTimeFormatter()
        rf.unitsStyle = .abbreviated
        return rf.localizedString(for: self, relativeTo: Date())
    }
}

extension TimeInterval {
    var hhmmss: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    var mmss: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
