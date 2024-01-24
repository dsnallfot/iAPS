import Combine
import Foundation
import SwiftDate
import Swinject

protocol FetchTreatmentsManager {}

final class BaseFetchTreatmentsManager: FetchTreatmentsManager, Injectable {
    private let processQueue = DispatchQueue(label: "BaseFetchTreatmentsManager.processQueue")
    @Injected() var nightscoutManager: NightscoutManager!
    @Injected() var tempTargetsStorage: TempTargetsStorage!
    @Injected() var carbsStorage: CarbsStorage!

    private var lifetime = Lifetime()
    private let timer = DispatchTimer(timeInterval: 1.minutes.timeInterval)

    init(resolver: Resolver) {
        injectServices(resolver)
        subscribe()
    }

    private func subscribe() {
        timer.publisher
            .receive(on: processQueue)
            .flatMap { _ -> AnyPublisher<([CarbsEntry], [TempTarget]), Never> in
                debug(.nightscout, "FetchTreatmentsManager heartbeat")
                debug(.nightscout, "Start fetching carbs and temptargets")
                return Publishers.CombineLatest(
                    self.nightscoutManager.fetchCarbs(),
                    self.nightscoutManager.fetchTempTargets()
                ).eraseToAnyPublisher()
            }
            .sink { carbs, targets in
                let filteredCarbs = carbs.filter { !($0.enteredBy?.contains(CarbsEntry.manual) ?? false) }
                if filteredCarbs.isNotEmpty {
                    self.carbsStorage.storeCarbs(filteredCarbs)
                }
                let filteredTargets = targets.filter { !($0.enteredBy?.contains(TempTarget.manual) ?? false) }
                if filteredTargets.isNotEmpty {
                    self.tempTargetsStorage.storeTempTargets(filteredTargets)
                }
            }

            // Test to resolve ns fetch carbs issue by adding actualDate
            /* .sink { carbs, targets in
                 // Map the fetched carbs, creating new instances with actualDate set to nil if it's missing
                 let processedCarbs = carbs.map { fetchedCarb in
                     if fetchedCarb.actualDate == nil {
                         return CarbsEntry(
                             id: fetchedCarb.id,
                             createdAt: fetchedCarb.createdAt,
                             actualDate: nil,
                             carbs: fetchedCarb.carbs,
                             fat: fetchedCarb.fat,
                             protein: fetchedCarb.protein,
                             note: fetchedCarb.note,
                             enteredBy: fetchedCarb.enteredBy,
                             isFPU: fetchedCarb.isFPU,
                             fpuID: fetchedCarb.fpuID
                         )
                     } else {
                         return fetchedCarb
                     }
                 }

                 // Filter and store the processed carbs
                 let filteredCarbs = processedCarbs.filter { !($0.enteredBy?.contains(CarbsEntry.manual) ?? false) }
                 if filteredCarbs.isNotEmpty {
                     self.carbsStorage.storeCarbs(filteredCarbs)
                 }

                 // Further processing for tempTargets (not modified in this example)
                 let filteredTargets = targets.filter { !($0.enteredBy?.contains(TempTarget.manual) ?? false) }
                 if filteredTargets.isNotEmpty {
                     self.tempTargetsStorage.storeTempTargets(filteredTargets)
                 }
             } */ // end of test code

            .store(in: &lifetime)
        timer.fire()
        timer.resume()
    }
}
