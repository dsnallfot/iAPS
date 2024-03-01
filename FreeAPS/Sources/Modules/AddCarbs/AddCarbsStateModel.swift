import CoreData
import Foundation
import SwiftUI

extension AddCarbs {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var carbsStorage: CarbsStorage!
        @Injected() var apsManager: APSManager!
        @Injected() var settings: SettingsManager!
        @Injected() private var keychain: Keychain!
        @Published var carbs: Decimal = 0
        @Published var date = Date()
        @Published var protein: Decimal = 0
        @Published var fat: Decimal = 0
        @Published var carbsRequired: Decimal?
        @Published var useFPUconversion: Bool = true
        @Published var dish: String = ""
        @Published var selection: Presets?
        @Published var summation: [String] = []
        @Published var maxCarbs: Decimal = 0
        @Published var note: String = ""
        @Published var id_: String = ""
        @Published var summary: String = ""
        @Published var skipBolus: Bool = false
        @Published var isEnabled = false
        @Published var carbRatio: Decimal = 0
        @Published var cob: Decimal = 0
        @Published var carbsUrl = ""

        let now = Date.now

        let coredataContext = CoreDataStack.shared.persistentContainer.viewContext

        override func subscribe() {
            subscribeSetting(\.useFPUconversion, on: $useFPUconversion) { useFPUconversion = $0 }
            carbsUrl = keychain.getValue(String.self, forKey: NightscoutConfig.Config.carbsUrlKey) ?? ""

            carbsRequired = provider.suggestion?.carbsReq
            carbRatio = provider.suggestion?.carbRatio ?? 0
            cob = provider.suggestion?.cob ?? 0
            maxCarbs = settings.settings.maxCarbs
            skipBolus = settingsManager.settings.skipBolusScreenAfterCarbs
        }

        func updateCurrentDate() {
            date = Date()
        }

        func savedSettings() {
            coredataContext.performAndWait {
                var overrideArray = [Override]()
                let requestEnabled = Override.fetchRequest() as NSFetchRequest<Override>
                let sortIsEnabled = NSSortDescriptor(key: "date", ascending: false)
                requestEnabled.sortDescriptors = [sortIsEnabled]
                try? overrideArray = coredataContext.fetch(requestEnabled)
                isEnabled = overrideArray.first?.enabled ?? false
            }
        }

        func add(_ continue_: Bool, fetch: Bool) {
            guard carbs > 0 || fat > 0 || protein > 0 else {
                showModal(for: nil)
                return
            }
            carbs = min(carbs, maxCarbs)
            id_ = UUID().uuidString

            let carbsToStore = [CarbsEntry(
                id: id_,
                createdAt: now,
                actualDate: date,
                carbs: carbs,
                fat: fat,
                protein: protein,
                note: note,
                enteredBy: CarbsEntry.manual,
                isFPU: false, fpuID: UUID().uuidString
            )]
            carbsStorage.storeCarbs(carbsToStore)

            if skipBolus, !continue_, !fetch {
                apsManager.determineBasalSync()
                showModal(for: nil)
            } else if carbs > 0 {
                saveToCoreData(carbsToStore)
                showModal(for: .bolus(waitForSuggestion: true, fetch: true))
                // apsManager.determineBasalSync() // Daniel: Added determinebasalsync to force update before entering bolusview also when show bolusscreen after addcarbs are active. reverted due to possible hang when exiting addcarbsview
            } else {
                hideModal()
            }
        }

        func deletePreset() {
            if selection != nil {
                try? coredataContext.delete(selection!)
                try? coredataContext.save()
                carbs = 0
                fat = 0
                protein = 0
            }
            selection = nil
        }

        // Refactored to avoid force unwrapping
        func removePresetFromNewMeal() {
            if let indexToRemove = summation.firstIndex(where: { $0 == selection?.dish! }),
               indexToRemove < summation.count, summation[indexToRemove] != ""
            {
                summation.remove(at: indexToRemove)
            }
        }

        func addPresetToNewMeal() {
            let test: String = selection?.dish ?? "dontAdd"
            if test != "dontAdd" {
                summation.append(test)
            }
        }

        func addNewPresetToWaitersNotepad(_ dish: String) {
            summation.append(dish)
        }

        func addToSummation() {
            summation.append(selection?.dish ?? "")
        }

        func waitersNotepad() -> String {
            var filteredArray = summation.filter { !$0.isEmpty }

            if carbs == 0, protein == 0, fat == 0 {
                filteredArray = []
            }

            guard filteredArray != [] else {
                return ""
            }
            var carbs_: Decimal = 0.0
            var fat_: Decimal = 0.0
            var protein_: Decimal = 0.0
            var presetArray = [Presets]()

            coredataContext.performAndWait {
                let requestPresets = Presets.fetchRequest() as NSFetchRequest<Presets>
                try? presetArray = coredataContext.fetch(requestPresets)
            }
            var waitersNotepad = [String]()
            var stringValue = ""

            for each in filteredArray {
                let countedSet = NSCountedSet(array: filteredArray)
                let count = countedSet.count(for: each)
                if each != stringValue {
                    waitersNotepad.append("\(count) \(each)")
                }
                stringValue = each

                for sel in presetArray {
                    if sel.dish == each {
                        carbs_ += (sel.carbs)! as Decimal
                        fat_ += (sel.fat)! as Decimal
                        protein_ += (sel.protein)! as Decimal
                        break
                    }
                }
            }
            let extracarbs = carbs - carbs_
            let extraFat = fat - fat_
            let extraProtein = protein - protein_
            var addedString = ""

            if extracarbs > 0, filteredArray.isNotEmpty {
                addedString += "Extra kh: \(extracarbs) "
            } else if extracarbs < 0 { addedString += "Raderade kh: \(extracarbs) " }

            if extraFat > 0, filteredArray.isNotEmpty {
                addedString += "Extra fett: \(extraFat) "
            } else if extraFat < 0 { addedString += "Raderat fett: \(extraFat) " }

            if extraProtein > 0, filteredArray.isNotEmpty {
                addedString += "Extra protein: \(extraProtein) "
            } else if extraProtein < 0 { addedString += "Raderat protein: \(extraProtein) " }

            if addedString != "" {
                waitersNotepad.append(addedString)
            }
            var waitersNotepadString = ""

            if waitersNotepad.count == 1 {
                waitersNotepadString = waitersNotepad[0]
            } else if waitersNotepad.count > 1 {
                for each in waitersNotepad {
                    if each != waitersNotepad.last {
                        waitersNotepadString += " " + each + ","
                    } else { waitersNotepadString += " " + each }
                }
            }
            return waitersNotepadString
        }

        func loadEntries(_ editMode: Bool) {
            if editMode {
                coredataContext.performAndWait {
                    var mealToEdit = [Meals]()
                    let requestMeal = Meals.fetchRequest() as NSFetchRequest<Meals>
                    let sortMeal = NSSortDescriptor(key: "createdAt", ascending: false)
                    requestMeal.sortDescriptors = [sortMeal]
                    requestMeal.fetchLimit = 1
                    try? mealToEdit = self.coredataContext.fetch(requestMeal)

                    self.carbs = Decimal(mealToEdit.first?.carbs ?? 0)
                    self.fat = Decimal(mealToEdit.first?.fat ?? 0)
                    self.protein = Decimal(mealToEdit.first?.protein ?? 0)
                    self.note = mealToEdit.first?.note ?? ""
                    self.id_ = mealToEdit.first?.id ?? ""
                }
            }
        }

        func saveToCoreData(_ stored: [CarbsEntry]) {
            coredataContext.performAndWait {
                let save = Meals(context: coredataContext)
                if let entry = stored.first {
                    save.createdAt = now
                    save.actualDate = entry.actualDate ?? Date.now
                    save.id = entry.id ?? ""
                    save.fpuID = entry.fpuID ?? ""
                    save.carbs = Double(entry.carbs)
                    save.fat = Double(entry.fat ?? 0)
                    save.protein = Double(entry.protein ?? 0)
                    save.note = entry.note
                    try? coredataContext.save()
                }
                print("meals 1: ID: " + (save.id ?? "").description + " FPU ID: " + (save.fpuID ?? "").description)
            }
        }
    }
}
