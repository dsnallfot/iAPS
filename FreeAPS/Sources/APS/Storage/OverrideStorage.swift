import Combine
import CoreData
import Foundation
import SwiftDate

final class OverrideStorage {
    let coredataContext = CoreDataStack.shared.persistentContainer.viewContext

    func fetchOverrides(interval: NSDate) -> [Override] {
        var overrideArray = [Override]()
        coredataContext.performAndWait {
            let requestOverrides = Override.fetchRequest() as NSFetchRequest<Override>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestOverrides.sortDescriptors = [sortOverride]
            requestOverrides.predicate = NSPredicate(
                format: "date > %@", interval
            )
            try? overrideArray = self.coredataContext.fetch(requestOverrides)
        }
        return overrideArray
    }

    func fetchLatestOverride() -> [Override] {
        var overrideArray = [Override]()
        coredataContext.performAndWait {
            let requestOverrides = Override.fetchRequest() as NSFetchRequest<Override>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestOverrides.sortDescriptors = [sortOverride]
            requestOverrides.fetchLimit = 1
            try? overrideArray = self.coredataContext.fetch(requestOverrides)
        }
        return overrideArray
    }

    func fetchNumberOfOverrides(numbers: Int) -> [Override] {
        var overrideArray = [Override]()
        coredataContext.performAndWait {
            let requestOverrides = Override.fetchRequest() as NSFetchRequest<Override>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestOverrides.sortDescriptors = [sortOverride]
            requestOverrides.fetchLimit = numbers
            try? overrideArray = self.coredataContext.fetch(requestOverrides)
        }
        return overrideArray
    }

    func fetchOverrideHistory(interval: NSDate) -> [OverrideHistory] {
        var overrideArray = [OverrideHistory]()
        coredataContext.performAndWait {
            let requestOverrides = OverrideHistory.fetchRequest() as NSFetchRequest<OverrideHistory>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestOverrides.sortDescriptors = [sortOverride]
            requestOverrides.predicate = NSPredicate(
                format: "date > %@", interval
            )
            try? overrideArray = self.coredataContext.fetch(requestOverrides)
        }
        return overrideArray
    }

    func cancelProfile() -> Double? {
        let scheduled = fetchLatestOverride().first
        var duration: Double?
        coredataContext.performAndWait { [self] in
            let profiles = Override(context: self.coredataContext)
            let history = OverrideHistory(context: self.coredataContext)
            if let latest = scheduled {
                history.duration = -1 * (latest.date ?? Date()).timeIntervalSinceNow.minutes
                print("History duration: \(history.duration) min")
                history.date = latest.date ?? Date()
                history.target = Double(latest.target ?? 100)
                duration = history.duration
            }
            profiles.enabled = false
            profiles.date = Date()
            try? self.coredataContext.save()
        }
        return duration
    }

    func overrideFromPreset(_ preset: OverridePresets) {
        coredataContext.performAndWait {
            let save = Override(context: coredataContext)
            save.date = Date.now
            save.id = preset.id
            save.end = preset.end
            save.start = preset.start
            save.advancedSettings = preset.advancedSettings
            save.cr = preset.cr
            save.duration = preset.duration
            save.enabled = true
            save.indefinite = preset.indefinite
            save.isPreset = true
            save.isf = preset.isf
            save.isfAndCr = preset.isfAndCr
            save.percentage = preset.percentage
            save.smbIsAlwaysOff = preset.smbIsAlwaysOff
            save.smbMinutes = preset.smbMinutes
            save.uamMinutes = preset.uamMinutes
            save.target = preset.target
            try? coredataContext.save()
        }
    }

    func fetchProfilePreset(_ name: String) -> OverridePresets? {
        var presetsArray = [OverridePresets]()
        var preset: OverridePresets?
        coredataContext.performAndWait {
            let requestPresets = OverridePresets.fetchRequest() as NSFetchRequest<OverridePresets>
            requestPresets.predicate = NSPredicate(
                format: "name == %@", name
            )
            try? presetsArray = self.coredataContext.fetch(requestPresets)

            guard let overridePreset = presetsArray.first else {
                return
            }
            preset = overridePreset
        }
        return preset
    }

    func fetchProfiles() -> OverridePresets? {
        var presetsArray = [OverridePresets]()
        coredataContext.performAndWait {
            let requestPresets = OverridePresets.fetchRequest() as NSFetchRequest<OverridePresets>
            requestPresets.predicate = NSPredicate(
                format: "name != %@", "" as String
            )
            try? presetsArray = self.coredataContext.fetch(requestPresets)
        }

        guard let last = presetsArray.first else {
            return nil
        }

        guard (last.date ?? Date.now).addingTimeInterval(Int(last.duration ?? 0).minutes.timeInterval) > Date(),
              (last.date ?? Date.now) <= Date.now,
              last.duration != 0
        else {
            return nil
        }
        return last
    }

    func fetchProfiles() -> [OverridePresets] {
        var presetsArray = [OverridePresets]()
        coredataContext.performAndWait {
            let requestPresets = OverridePresets.fetchRequest() as NSFetchRequest<OverridePresets>
            requestPresets.predicate = NSPredicate(
                format: "name != %@", "" as String
            )
            try? presetsArray = self.coredataContext.fetch(requestPresets)
        }
        return presetsArray
    }

    func activateOverride(_ override: Override) {
        var overrideArray = [Override]()
        coredataContext.performAndWait {
            let save = Override(context: coredataContext)
            save.date = Date.now
            save.id = override.id
            save.end = override.end
            save.start = override.start
            save.advancedSettings = override.advancedSettings
            save.cr = override.cr
            save.duration = override.duration
            save.enabled = override.enabled
            save.indefinite = override.indefinite
            save.isPreset = override.isPreset
            save.isf = override.isf
            save.isfAndCr = override.isfAndCr
            save.percentage = override.percentage
            save.smbIsAlwaysOff = override.smbIsAlwaysOff
            save.smbMinutes = override.smbMinutes
            save.uamMinutes = override.uamMinutes
            save.target = override.target
            try? coredataContext.save()
        }
    }

    func isActive() -> Bool {
        var overrideArray = [Override]()
        coredataContext.performAndWait {
            let requestOverrides = Override.fetchRequest() as NSFetchRequest<Override>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestOverrides.sortDescriptors = [sortOverride]
            requestOverrides.fetchLimit = 1
            try? overrideArray = self.coredataContext.fetch(requestOverrides)
        }
        guard let lastOverride = overrideArray.first else {
            return false
        }
        return lastOverride.enabled
    }

    func isPresetName() -> String? {
        var presetsArray = [OverridePresets]()
        var overrideArray = [Override]()
        var name: String?
        coredataContext.performAndWait {
            let requestOverrides = Override.fetchRequest() as NSFetchRequest<Override>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestOverrides.sortDescriptors = [sortOverride]
            requestOverrides.fetchLimit = 1
            try? overrideArray = self.coredataContext.fetch(requestOverrides)

            if let or = overrideArray.first, let id = or.id {
                let requestPresets = OverridePresets.fetchRequest() as NSFetchRequest<OverridePresets>
                requestPresets.predicate = NSPredicate(
                    format: "id == %@", id
                )
                try? presetsArray = self.coredataContext.fetch(requestPresets)

                guard let presets = presetsArray.first, let presetName = presets.name else {
                    return
                }
                name = presetName
            }
        }
        return name
    }

    func fetchPreset(_ name: String) -> (id: String?, preset: OverridePresets?) {
        var presetsArray = [OverridePresets]()
        var id: String?
        var overridePreset: OverridePresets?
        coredataContext.performAndWait {
            let requestPresets = OverridePresets.fetchRequest() as NSFetchRequest<OverridePresets>
            requestPresets.predicate = NSPredicate(
                format: "name == %@", name
            )
            try? presetsArray = self.coredataContext.fetch(requestPresets)

            guard let preset = presetsArray.first else {
                return
            }
            guard let id_ = preset.id else {
                return
            }
            id = id_
            overridePreset = preset
        }
        return (id, overridePreset)
    }

    func overrideFromPreset(_ preset: OverridePresets, _ id: String) {
        coredataContext.performAndWait {
            coredataContext.performAndWait {
                let save = Override(context: coredataContext)
                save.date = Date.now
                save.id = id
                save.end = preset.end
                save.start = preset.start
                save.advancedSettings = preset.advancedSettings
                save.cr = preset.cr
                save.duration = preset.duration
                save.enabled = true
                save.indefinite = preset.indefinite
                save.isPreset = true
                save.isf = preset.isf
                save.isfAndCr = preset.isfAndCr
                save.percentage = preset.percentage
                save.smbIsAlwaysOff = preset.smbIsAlwaysOff
                save.smbMinutes = preset.smbMinutes
                save.uamMinutes = preset.uamMinutes
                if (preset.target ?? 0) as Decimal > 6 {
                    save.target = preset.target
                } else { save.target = 6 }
                try? coredataContext.save()
            }
        }
    }

    func addToNotUploaded(_ add: Int16) {
        var currentCount = [NotUploaded]()
        coredataContext.performAndWait {
            let requestCount = NotUploaded.fetchRequest() as NSFetchRequest<NotUploaded>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestCount.sortDescriptors = [sortOverride]
            requestCount.fetchLimit = 1
            try? currentCount = self.coredataContext.fetch(requestCount)

            var log: Int16 = currentCount.first?.number ?? 0

            let save = NotUploaded(context: coredataContext)
            if currentCount.first != nil, log != 0 {
                save.number += add
                save.date = Date.now
                try? coredataContext.save()
                log = save.number
            } else if add > 0 {
                save.number = add
                save.date = Date.now
                try? coredataContext.save()
                log = save.number
            } else if add < 0 {
                if (currentCount.first?.number ?? 0) + add >= 0 {
                    save.number = add
                    save.date = Date.now
                    try? coredataContext.save()
                    log = save.number
                } else {
                    save.number = 0
                    save.date = Date.now
                    try? coredataContext.save()
                    log = save.number
                }
            }
            debug(.service, "CoreData. addToNotUploaded Overrides incremented. Current amount: \(log)")
        }
    }

    func countNotUploaded() -> Int? {
        var currentCount = [NotUploaded]()
        coredataContext.performAndWait {
            let requestCount = NotUploaded.fetchRequest() as NSFetchRequest<NotUploaded>
            let sortOverride = NSSortDescriptor(key: "date", ascending: false)
            requestCount.predicate = NSPredicate(
                format: "date > %@", Date().addingTimeInterval(-2.days.timeInterval) as NSDate
            )
            requestCount.sortDescriptors = [sortOverride]
            requestCount.fetchLimit = 1
            try? currentCount = self.coredataContext.fetch(requestCount)
        }
        if let latest = currentCount.first, latest.number > 0 {
            return Int(latest.number)
        }
        return nil
    }
}
