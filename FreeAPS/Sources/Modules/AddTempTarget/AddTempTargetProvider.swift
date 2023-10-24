import Foundation

extension AddTempTarget {
    final class Provider: BaseProvider, AddTempTargetProvider {
        @Injected() var tempTargetsStorage: TempTargetsStorage!

        func tempTargets(hours: Int) -> [TempTarget] {
            tempTargetsStorage.recent().filter {
                $0.createdAt.addingTimeInterval(hours.hours.timeInterval) > Date()
            }
        }

        func tempTarget() -> TempTarget? {
            tempTargetsStorage.current()
        }
    }
}
