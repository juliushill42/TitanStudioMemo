import Foundation
import Combine

@MainActor
final class StemJob: ObservableObject, Identifiable {
    let id: UUID
    @Published private(set) var model: StemJobModel
    @Published private(set) var state: AsyncState<StemJobModel> = .idle

    private let engine: StemSeparationEngine

    init(model: StemJobModel, engine: StemSeparationEngine) {
        self.id = model.id
        self.model = model
        self.engine = engine
    }

    func run() async {
        state = .loading
        model.status = .processing
        do {
            let completed = try await engine.separate(job: model)
            model = completed
            state = .success(completed)
        } catch let e as AppError {
            model.status = .failed
            model.errorMessage = e.localizedDescription
            state = .failure(e)
        } catch {
            model.status = .failed
            state = .failure(.unknown(error))
        }
    }
}
