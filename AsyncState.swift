import Foundation

enum AsyncState<T: Sendable>: Sendable {
    case idle
    case loading
    case success(T)
    case failure(AppError)

    var isLoading: Bool { if case .loading = self { return true }; return false }
    var isIdle: Bool    { if case .idle    = self { return true }; return false }

    var value: T? {
        if case .success(let v) = self { return v }
        return nil
    }
    var error: AppError? {
        if case .failure(let e) = self { return e }
        return nil
    }
}

// MARK: - Job progress wrapper
struct JobProgress: Sendable {
    let fractionCompleted: Double
    let phase: String

    static let idle     = JobProgress(fractionCompleted: 0, phase: "Idle")
    static let complete = JobProgress(fractionCompleted: 1, phase: "Complete")
}
