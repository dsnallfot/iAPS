import CoreData
import SwiftUI
import Swinject

extension Bolus {
    struct AlternativeBolusCalcRootView: BaseView {
        let resolver: Resolver
        let waitForSuggestion: Bool
        let fetch: Bool
        @StateObject var state: StateModel
        @State private var showInfo = false
        @State private var exceededMaxBolus = false
        @State private var exceededMaxBolus3 = false
        @State private var keepForNextWiew: Bool = false
        @State private var carbsWarning = false
        @State private var displayError = false
        @State private var presentInfo = false
        @Environment(\.colorScheme) var colorScheme

        @FetchRequest(
            entity: Meals.entity(),
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]
        ) var meal: FetchedResults<Meals>

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var mealFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            } else { formatter.maximumFractionDigits = 0 }
            return formatter
        }

        private var fractionDigits: Int {
            if state.units == .mmolL {
                return 1
            } else { return 0 }
        }

        var body: some View {
            Form {
                if fetch {
                    Section {
                        mealEntries
                    } header: { Text("Meal Summary") }
                }

                /* .font(.subheadline) */
                Section {
                    if state.sweetMeals || state.fattyMeals {
                        HStack {
                            Text("Anpassa dos:")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Spacer()
                            if state.fattyMeals {
                                Text("Hög FP%")
                                    .foregroundColor(.brown)
                                    .font(.footnote)

                                Toggle(isOn: $state.useFattyMealCorrectionFactor) {}
                                    .toggleStyle(CheckboxToggleStyle())
                                    .font(.footnote)
                                    .foregroundColor(.brown)
                                    .onChange(of: state.useFattyMealCorrectionFactor) { _ in
                                        state.insulinCalculated = state.calculateInsulin()
                                        if state.useFattyMealCorrectionFactor {
                                            state.useSuperBolus = false
                                        }
                                    }
                            }
                            if state.sweetMeals {
                                Text(" Superbolus")
                                    .foregroundColor(.cyan)
                                    .font(.footnote)

                                Toggle(isOn: $state.useSuperBolus) {}
                                    .toggleStyle(CheckboxToggleStyle())
                                    .font(.footnote)
                                    .foregroundColor(.cyan)
                                    .onChange(of: state.useSuperBolus) { _ in
                                        state.insulinCalculated = state.calculateInsulin()
                                        if state.useSuperBolus {
                                            state.useFattyMealCorrectionFactor = false
                                        }
                                    }
                            }
                        }
                    }
                }
                // Section {
                HStack {
                    if state.waitForSuggestion {
                        HStack {
                            Image(systemName: "timer").foregroundColor(.secondary)
                            Text("Beräknar...").foregroundColor(.secondary)
                        }
                    } else if state.error && state.insulinCalculated > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Vänta med att ge bolus")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                        }
                    } else if state.insulinCalculated > state.insulinRecommended {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Vänta med att ge bolus")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                        }
                    } else if state.insulinCalculated <= 0 {
                        HStack {
                            Image(systemName: "x.circle.fill")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Ingen bolus rekommenderas")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Förslag bolusdos")
                                .foregroundColor(.green)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                        }
                    }
                    Spacer()

                    if state.waitForSuggestion {
                        ActivityIndicator(isAnimating: .constant(true), style: .medium)

                    } else if state.error && state.insulinCalculated > 0 {
                        Text(
                            formatter
                                .string(from: state.insulinCalculated as NSNumber)! +
                                NSLocalizedString(" U", comment: "Insulin unit")
                        ).foregroundColor(.orange)
                    } else if state.insulinCalculated > state.insulinRecommended {
                        Text(
                            formatter
                                .string(from: state.insulinRecommended as NSNumber)! +
                                NSLocalizedString(" U", comment: "Insulin unit")
                        ).foregroundColor(.orange)
                    } else if state.insulinCalculated <= 0 {
                        Text(
                            formatter
                                .string(from: state.insulinCalculated as NSNumber)! +
                                NSLocalizedString(" U", comment: "Insulin unit")
                        ).foregroundColor(.loopRed)
                    } else {
                        Text(
                            formatter
                                .string(from: state.insulinCalculated as NSNumber)! +
                                NSLocalizedString(" U", comment: "Insulin unit")
                        ).foregroundColor(.green)
                    }
                }

                .contentShape(Rectangle())
                .onTapGesture {
                    if state.error, state.insulinCalculated > 0 {
                        displayError = true
                    } else if state.insulinCalculated > state.insulinRecommended {
                        displayError = true
                    } else if state.insulinCalculated <= 0 {
                        showInfo.toggle()
                        state.insulinCalculated = state.calculateInsulin() // Call the calculateInsulin function
                    } else {
                        state.amount = state.insulinCalculated
                    }
                }

                if !state.waitForSuggestion {
                    HStack {
                        Text("Bolus Amount").fontWeight(.semibold)
                        Spacer()
                        DecimalTextField(
                            "0,00",
                            value: $state.amount,
                            formatter: formatter,
                            autofocus: true,
                            cleanInput: true
                        )
                        Text(exceededMaxBolus3 ? "☠️" : "U").fontWeight(.semibold)
                    }
                    .onChange(of: state.amount) { newValue in
                        if newValue > state.maxBolus * 3 {
                            exceededMaxBolus3 = true
                            exceededMaxBolus = true
                        } else if newValue > state.maxBolus {
                            exceededMaxBolus = true
                        } else {
                            exceededMaxBolus = false
                            exceededMaxBolus3 = false
                        }
                    }
                }

                if state.amount > 0 {
                    Section {
                        let maxamountbolus = Double(state.maxBolus)
                        let formattedMaxAmountBolus = String(maxamountbolus)

                        Button {
                            keepForNextWiew = true
                            state.add()
                        }
                        label: {
                            HStack {
                                if exceededMaxBolus {
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(.loopRed)
                                }
                                Text(
                                    exceededMaxBolus ? "Inställd maxgräns: \(formattedMaxAmountBolus)E   " :
                                        "Ge bolusdos"
                                )
                                .font(.title3.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .disabled(
                                state.amount <= 0 || state.amount > state.maxBolus
                            )
                        }
                    }
                }
                if state.amount <= 0 {
                    Section {
                        Button {
                            keepForNextWiew = true
                            state.showModal(for: nil)
                        } label: {
                            Text("Continue without bolus")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.title3)
                        // .foregroundColor(state.amount > 0 ? .secondary : .accentColor)
                    }
                    if state.amount > 0 {
                        Section {
                            let maxamountbolus = Double(state.maxBolus)
                            let formattedMaxAmountBolus = String(maxamountbolus)

                            Button {
                                keepForNextWiew = true
                                state.add()
                            }
                            label: {
                                HStack {
                                    if exceededMaxBolus {
                                        Image(systemName: "x.circle.fill")
                                            .foregroundColor(.loopRed)
                                    }
                                    Text(
                                        exceededMaxBolus ? "Inställd maxgräns: \(formattedMaxAmountBolus)E   " :
                                            "Ge bolusdos"
                                    )
                                    .font(.title3.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .disabled(
                                    state.amount <= 0 || state.amount > state.maxBolus
                                )
                            }
                        }
                        if state.amount <= 0 {
                            Section {
                                Button {
                                    keepForNextWiew = true
                                    state.showModal(for: nil)
                                }
                                label: { Text("Continue without bolus") }.frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $displayError) {
                Alert(
                    title: Text("Varning!"),
                    message: Text("\n" + alertString() + "\n"),
                    primaryButton: .destructive(
                        Text("Add"),
                        action: {
                            if state.insulinCalculated > state.insulinRecommended {
                                state.amount = state.insulinRecommended
                                displayError = false
                            } else {
                                state.amount = state.insulinCalculated
                                displayError = false
                            }
                        }
                    ),
                    secondaryButton: .cancel()
                )
            }

            .navigationBarTitle("Enact Bolus", displayMode: .inline)
            .navigationBarItems(
                leading: Button {
                    carbssView()
                }
                label: {
                    Group {
                        if fetch {
                            Image(systemName: "chevron.left").fontWeight(.semibold)
                        } else { Image(systemName: "plus.circle.fill") }
                        Text(fetch ? "Tillbaka" : "Måltid")
                    }
                },

                trailing: Button { showInfo.toggle() }
                label: { Image(systemName: "info.circle.fill") }
            )
            .onAppear {
                configureView {
                    state.waitForSuggestionInitial = waitForSuggestion
                    state.waitForSuggestion = waitForSuggestion
                    state.insulinCalculated = state.calculateInsulin()
                }
                // Additional code to automatically check the checkbox
                if fetch {
                    if let carbs = meal.first?.carbs,
                       let fat = meal.first?.fat,
                       let protein = meal.first?.protein
                    {
                        let fatPercentage = (fat + protein) / (carbs + fat + protein)

                        // Convert state.fattyMealTrigger to a Double
                        let fattyMealTriggerDouble = NSDecimalNumber(decimal: state.fattyMealTrigger).doubleValue

                        if fatPercentage > fattyMealTriggerDouble {
                            state.useFattyMealCorrectionFactor = true
                        }
                    }
                }
            }
            .onDisappear {
                state.useFattyMealCorrectionFactor = false
                if fetch, hasFatOrProtein, !keepForNextWiew {
                    state.delete(deleteTwice: true, id: meal.first?.id ?? "")
                } else if fetch, !keepForNextWiew {
                    state.delete(deleteTwice: false, id: meal.first?.id ?? "")
                }
            }
            .sheet(isPresented: $showInfo) {
                bolusInfoAlternativeCalculator
            }
        }

        // calculation showed in sheet
        var bolusInfoAlternativeCalculator: some View {
            NavigationView {
                VStack {
                    let unit = NSLocalizedString(
                        " U",
                        comment: "Unit in number of units delivered (keep the space character!)"
                    )
                    VStack {
                        VStack {
                            VStack(spacing: 2) {
                                if fetch {
                                    VStack {
                                        Group {
                                            HStack {
                                                Text("Aktuell måltid")
                                                    .fontWeight(.semibold)
                                                Spacer()
                                            }
                                            if let carbs = meal.first?.carbs, carbs > 0 {
                                                HStack {
                                                    Text("Carbs")
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text(mealFormatter.string(from: carbs as NSNumber) ?? "")
                                                    Text("g").foregroundColor(.secondary)
                                                }
                                            }
                                            if let protein = meal.first?.protein, protein > 0 {
                                                HStack {
                                                    Text("Protein")
                                                        .foregroundColor(.brown)
                                                    Spacer()
                                                    Text(mealFormatter.string(from: protein as NSNumber) ?? "")
                                                        .foregroundColor(.brown)
                                                    Text("g").foregroundColor(.brown)
                                                }
                                            }
                                            if let fat = meal.first?.fat, fat > 0 {
                                                HStack {
                                                    Text("Fat")
                                                        .foregroundColor(.brown)
                                                    Spacer()
                                                    Text(mealFormatter.string(from: fat as NSNumber) ?? "")
                                                        .foregroundColor(.brown)
                                                    Text("g").foregroundColor(.brown)
                                                }
                                            }
                                            if let note = meal.first?.note, note != "" {
                                                HStack {
                                                    Text("Note")
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text(note)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                    }
                                    if fetch { Divider().fontWeight(.bold).padding(2) }
                                }
                                Group {
                                    HStack {
                                        Text("Variabler")
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.bottom, 1)

                                    HStack {
                                        Text("Aktuell ISF:")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        let isf = state.isf
                                        Text(isf.formatted())
                                        Text(state.units.rawValue + NSLocalizedString("/E", comment: "/Insulin unit"))
                                            .foregroundColor(.secondary)
                                    }

                                    HStack {
                                        Text("Målvärde:")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        let target = state.units == .mmolL ? state.target.asMmolL : state.target
                                        Text(
                                            target
                                                .formatted(
                                                    .number.grouping(.never).rounded()
                                                        .precision(.fractionLength(fractionDigits))
                                                )
                                        )
                                        Text(state.units.rawValue)
                                            .foregroundColor(.secondary)
                                    }
                                    // Basal dont update for some reason. needs to check. not crucial info in the calc view right now
                                    HStack {
                                        Text("Aktuell basal:")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        let basal = state.currentBasal
                                        Text(basal.formatted())
                                        Text(NSLocalizedString("E/h", comment: " Units per hour"))
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text("Aktuell CR (insulinkvot):")
                                            .foregroundColor(.secondary)
                                        Spacer()

                                        Text(state.carbRatio.formatted())
                                        Text(NSLocalizedString("g/E", comment: " grams per Unit"))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.bottom, 2)
                                }

                                Divider().fontWeight(.bold).padding(2)

                                Group {
                                    HStack {
                                        if state.evBG > 0 {
                                            Text("(Oref) Blodsockerprognos:")
                                                .foregroundColor(.secondary)
                                                .italic()
                                            Spacer()
                                            let eventualBG = Double(state.evBG) * 0.0555
                                            Text(
                                                eventualBG
                                                    .formatted(
                                                        .number.grouping(.never).rounded()
                                                            .precision(.fractionLength(fractionDigits))
                                                    )
                                            )
                                            .italic()
                                            Text("mmol/L")
                                                .foregroundColor(.secondary)
                                                .italic()
                                        }
                                    }

                                    HStack {
                                        if state.insulinCalculated > state.insulinRecommended {
                                            Text("(Oref) Insulinrekommendation:")
                                                .foregroundColor(.insulin)
                                                .italic()
                                            Spacer()
                                            Text(state.insulinRecommended.formatted())
                                                .foregroundColor(.insulin)
                                                .italic()

                                            Text(NSLocalizedString("E", comment: " grams per Unit"))
                                                .foregroundColor(.insulin)
                                                .italic()
                                        } else {
                                            Text("(Oref) Insulinrekommendation:")
                                                .foregroundColor(.secondary)
                                                .italic()
                                            Spacer()
                                            Text(state.insulinRecommended.formatted())
                                                .italic()

                                            Text(NSLocalizedString("E", comment: " grams per Unit"))
                                                .foregroundColor(.secondary)
                                                .italic()
                                            // }
                                        }
                                    }
                                    Divider().fontWeight(.bold).padding(2)
                                    Group {
                                        HStack {
                                            if state.insulinCalculated == state.maxBolus {
                                                Text("Inställd maxbolus:")
                                                    .foregroundColor(.purple)
                                                Spacer()
                                                let maxBolus = state.maxBolus
                                                Text(maxBolus.formatted())
                                                    .foregroundColor(.purple)
                                                Text(NSLocalizedString("E", comment: " Units"))
                                                    .foregroundColor(.purple)
                                            } else {
                                                Text("Inställd maxbolus:")
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                let maxBolus = state.maxBolus
                                                Text(maxBolus.formatted())
                                                Text(NSLocalizedString("E", comment: " Units"))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        HStack {
                                            Text("Inställda max kolhydrater:")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            let maxCarbs = state.maxCarbs
                                            Text(maxCarbs.formatted())
                                            Text(NSLocalizedString("g", comment: "grams"))
                                                .foregroundColor(.secondary)
                                        }
                                        HStack {
                                            Text("Inställd faktor manuell bolus:")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            let fraction = state.fraction * 100
                                            Text(fraction.formatted())
                                            Text("%")
                                                .foregroundColor(.secondary)
                                        }
                                        if state.useFattyMealCorrectionFactor {
                                            HStack {
                                                Text("Inställd faktor fet/proteinrik måltid :")
                                                    .foregroundColor(.brown)
                                                Spacer()
                                                let fraction = state.fattyMealFactor * 100
                                                Text(fraction.formatted())
                                                    .foregroundColor(.brown)
                                                Text("%")
                                                    .foregroundColor(.brown)
                                            }
                                        }
                                        if state.useSuperBolus {
                                            HStack {
                                                Text("Superbolus")
                                                    .foregroundColor(.cyan)
                                                Spacer()
                                                let superBolusInsulin = state.superBolusInsulin
                                                Text(superBolusInsulin.formatted())
                                                    .foregroundColor(.cyan)
                                                Text(" U")
                                                    .foregroundColor(.cyan)
                                            }
                                        }
                                    }
                                }

                                Divider().fontWeight(.bold).padding(2)
                                VStack(spacing: 2) {
                                    HStack {
                                        Text("Boluskalkyl")
                                        Spacer()
                                        Text("Behov +/-  E")
                                    }
                                    .foregroundColor(.primary).fontWeight(.semibold)
                                    .padding(.top, 4)
                                    .padding(.bottom, 2)

                                    let carbs = meal.first?.carbs
                                    let formattedCarbs = Decimal(carbs!)

                                    if fetch {
                                        if let carbs = meal.first?.carbs, carbs > 0 {
                                            HStack(alignment: .center, spacing: nil) {
                                                Text("Kh aktuell måltid:")
                                                    .foregroundColor(.secondary)
                                                    .frame(minWidth: 105, alignment: .leading)

                                                Text(formattedCarbs.formatted())
                                                    .frame(minWidth: 50, alignment: .trailing)

                                                Text("g").foregroundColor(.secondary)
                                                    .frame(minWidth: 50, alignment: .leading)

                                                Image(systemName: "arrow.right")
                                                    .frame(minWidth: 15, alignment: .trailing)
                                                Spacer()
                                                let insulinMeal = formattedCarbs / state.carbRatio
                                                // rounding
                                                let insulinMealAsDouble = NSDecimalNumber(decimal: insulinMeal)
                                                    .doubleValue
                                                let roundedInsulinMeal = Decimal(round(100 * insulinMealAsDouble) / 100)
                                                Text(roundedInsulinMeal.formatted())
                                                Text(unit)
                                                    .foregroundColor(.secondary)
                                            }
                                            HStack(alignment: .center, spacing: nil) {
                                                Text("COB:")
                                                    .foregroundColor(.secondary)
                                                    .frame(minWidth: 105, alignment: .leading)

                                                let cob = state.cob - formattedCarbs
                                                Text(cob.formatted())
                                                    .frame(minWidth: 50, alignment: .trailing)

                                                let unitGrams = NSLocalizedString("g", comment: "grams")
                                                Text(unitGrams).foregroundColor(.secondary)
                                                    .frame(minWidth: 50, alignment: .leading)

                                                Image(systemName: "arrow.right")
                                                    .frame(minWidth: 15, alignment: .trailing)
                                                Spacer()
                                                let insulinCob = state.wholeCobInsulin - formattedCarbs / state.carbRatio
                                                // rounding
                                                let insulinCobAsDouble = NSDecimalNumber(decimal: insulinCob).doubleValue
                                                let roundedInsulinCob = Decimal(round(100 * insulinCobAsDouble) / 100)
                                                Text(roundedInsulinCob.formatted())
                                                Text(unit)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    } else {
                                        HStack(alignment: .center, spacing: nil) {
                                            Text("COB:")
                                                .foregroundColor(.secondary)
                                                .frame(minWidth: 105, alignment: .leading)

                                            let cob = state.cob
                                            Text(cob.formatted())
                                                .frame(minWidth: 50, alignment: .trailing)

                                            let unitGrams = NSLocalizedString("g", comment: "grams")
                                            Text(unitGrams).foregroundColor(.secondary)
                                                .frame(minWidth: 50, alignment: .leading)

                                            Image(systemName: "arrow.right")
                                                .frame(minWidth: 15, alignment: .trailing)
                                            Spacer()
                                            let insulinCob = state.wholeCobInsulin
                                            // rounding
                                            let insulinCobAsDouble = NSDecimalNumber(decimal: insulinCob).doubleValue
                                            let roundedInsulinCob = Decimal(round(100 * insulinCobAsDouble) / 100)
                                            Text(roundedInsulinCob.formatted())
                                            Text(unit)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    HStack(alignment: .center, spacing: nil) {
                                        Text("IOB:")
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 105, alignment: .leading)

                                        let iob = state.iob
                                        // rounding
                                        let iobAsDouble = NSDecimalNumber(decimal: iob).doubleValue
                                        let roundedIob = Decimal(round(100 * iobAsDouble) / 100)
                                        Text(roundedIob.formatted())
                                            .frame(minWidth: 50, alignment: .trailing)

                                        Text(unit)
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 50, alignment: .leading)

                                        Image(systemName: "arrow.right")
                                            .frame(minWidth: 15, alignment: .trailing)
                                        Spacer()
                                        let iobCalc = state.iobInsulinReduction
                                        // rounding
                                        let iobCalcAsDouble = NSDecimalNumber(decimal: iobCalc).doubleValue
                                        let roundedIobCalc = Decimal(round(100 * iobCalcAsDouble) / 100)
                                        Text(roundedIobCalc.formatted())
                                        Text(unit).foregroundColor(.secondary)
                                    }
                                    HStack(alignment: .center, spacing: nil) {
                                        Text("Blodsocker:")
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 105, alignment: .leading)

                                        let glucose = state.units == .mmolL ? state.currentBG.asMmolL : state.currentBG
                                        Text(
                                            glucose
                                                .formatted(
                                                    .number.grouping(.never).rounded()
                                                        .precision(.fractionLength(fractionDigits))
                                                )
                                        )
                                        .frame(minWidth: 50, alignment: .trailing)
                                        Text(state.units.rawValue)
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 50, alignment: .leading)

                                        Image(systemName: "arrow.right")
                                            .frame(minWidth: 15, alignment: .trailing)
                                        Spacer()
                                        let targetDifferenceInsulin = state.targetDifferenceInsulin
                                        // rounding
                                        let targetDifferenceInsulinAsDouble =
                                            NSDecimalNumber(decimal: targetDifferenceInsulin)
                                                .doubleValue
                                        let roundedTargetDifferenceInsulin =
                                            Decimal(round(100 * targetDifferenceInsulinAsDouble) / 100)

                                        Text(roundedTargetDifferenceInsulin.formatted())

                                        Text(unit)

                                            .foregroundColor(.secondary)
                                    }
                                    HStack(alignment: .center, spacing: nil) {
                                        Text("15 min trend:")
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 105, alignment: .leading)

                                        let trend = state.units == .mmolL ? state.deltaBG.asMmolL : state.deltaBG
                                        Text(
                                            trend
                                                .formatted(
                                                    .number.grouping(.never).rounded()
                                                        .precision(.fractionLength(fractionDigits))
                                                )
                                        )
                                        .frame(minWidth: 50, alignment: .trailing)
                                        Text(state.units.rawValue).foregroundColor(.secondary)
                                            .frame(minWidth: 50, alignment: .leading)

                                        Image(systemName: "arrow.right")
                                            .frame(minWidth: 15, alignment: .trailing)
                                        Spacer()
                                        let trendInsulin = state.fifteenMinInsulin
                                        // rounding
                                        let trendInsulinAsDouble = NSDecimalNumber(decimal: trendInsulin).doubleValue
                                        let roundedTrendInsulin = Decimal(round(100 * trendInsulinAsDouble) / 100)
                                        Text(roundedTrendInsulin.formatted())
                                        Text(unit)
                                            .foregroundColor(.secondary)
                                    }
                                    // }
                                }
                                Divider().fontWeight(.bold).padding(2)

                                HStack {
                                    Text("Summa beräknat bolusbehov:")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    let insulin = state.roundedWholeCalc
                                    Text(insulin.formatted())
                                        .foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                                    Text(unit)
                                        .foregroundColor(.primary)
                                }
                                .fontWeight(.semibold)
                                .padding(.top, 1)
                                .padding(.bottom, 1)

                                Divider().fontWeight(.bold).padding(2)

                                HStack {
                                    if state.error && state.insulinCalculated > 0 {
                                        Text("Vänta med bolus:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                            .font(.system(size: 16))
                                    } else if state.insulinCalculated > state.insulinRecommended {
                                        Text("Vänta med bolus:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                            .font(.system(size: 16))
                                    } else if state.insulinCalculated <= 0 {
                                        Text("Ingen bolus rek:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.loopRed)
                                            .font(.system(size: 16))
                                    } else {
                                        Text("Förslag bolusdos:")
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                    }

                                    Spacer()

                                    if !state.useSuperBolus {
                                        let fraction = state.fraction * 100
                                        Text(fraction.formatted())
                                        Text("%  x ")
                                            .foregroundColor(.secondary)

                                        if state.useFattyMealCorrectionFactor {
                                            let fattyMealFactor = state.fattyMealFactor * 100
                                            Text(fattyMealFactor.formatted())
                                                .foregroundColor(.brown)
                                            Text("%  x ")
                                                .foregroundColor(.secondary)
                                        }
                                        let insulin = state.roundedWholeCalc
                                        Text(insulin.formatted())
                                            .foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                                        Text(unit)
                                            .foregroundColor(.secondary)
                                        Text(" = ")
                                            .foregroundColor(.secondary)
                                    } else {
                                        // roundedWholeCalc
                                        let insulin = state.roundedWholeCalc
                                        Text(insulin.formatted())
                                            .foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                                        Text(" U")
                                        // plus
                                        Text(" + ")
                                            .foregroundColor(.secondary)
                                        // superBolusInsulin
                                        let superBolusInsulin = state.superBolusInsulin
                                        Text(superBolusInsulin.formatted())
                                            .foregroundColor(.cyan)
                                        Text(" U")
                                            .foregroundColor(.cyan)
                                        Text(" = ")
                                            .foregroundColor(.secondary)
                                    }
                                    if state.insulinCalculated > state.insulinRecommended {
                                        let result = state.insulinRecommended
                                        // rounding
                                        let resultAsDouble = NSDecimalNumber(decimal: result).doubleValue
                                        let roundedResult = (resultAsDouble / 0.05).rounded() * 0.05
                                        if state.error && state.insulinCalculated > 0 {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.orange)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                                .font(.system(size: 16))
                                        } else if state.insulinCalculated > state.insulinRecommended {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.orange)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                                .font(.system(size: 16))
                                        } else if state.insulinCalculated <= 0 {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.loopRed)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.loopRed)
                                                .font(.system(size: 16))
                                        } else {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.green)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.green)
                                                .font(.system(size: 16))
                                        }
                                    } else {
                                        let result = state.insulinCalculated
                                        // rounding
                                        let resultAsDouble = NSDecimalNumber(decimal: result).doubleValue
                                        let roundedResult = (resultAsDouble / 0.05).rounded() * 0.05
                                        if state.error && state.insulinCalculated > 0 {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.orange)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                                .font(.system(size: 16))
                                        } else if state.insulinCalculated > state.insulinRecommended {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.orange)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                                .font(.system(size: 16))
                                        } else if state.insulinCalculated <= 0 {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.loopRed)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.loopRed)
                                                .font(.system(size: 16))
                                        } else {
                                            Text(roundedResult.formatted())
                                                .fontWeight(.bold)
                                                .font(.system(size: 16))
                                                .foregroundColor(.green)
                                            Text(unit)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.green)
                                                .font(.system(size: 16))
                                        }
                                    }
                                }
                                .onTapGesture {
                                    if state.insulinCalculated > state.insulinRecommended {
                                        state.amount = state.insulinRecommended
                                    } else {
                                        state.amount = state.insulinCalculated
                                    }
                                    showInfo.toggle()
                                }

                                .padding(.top, 2)

                                let maxamountbolus = Double(state.maxBolus)
                                let formattedMaxAmountBolus = String(maxamountbolus)
                                let orefamountbolus = Double(state.insulinRecommended)
                                let formattedOrefAmountBolus = String(format: "%.2f", orefamountbolus)
                                if state.insulinCalculated == state.maxBolus {
                                    Text("Obs! Förslaget begränsas av inställd maxbolus: \(formattedMaxAmountBolus) E")
                                        .foregroundColor(.purple).italic()
                                        .padding(.top, 3)
                                        .padding(.bottom, 3)
                                } else if state.insulinCalculated > state.insulinRecommended {
                                    Text("Obs! Förslaget begränsas av (oref) insulinrek: \(formattedOrefAmountBolus) E")
                                        .foregroundColor(.insulin).italic()
                                        .padding(.top, 3)
                                        .padding(.bottom, 3)
                                }
                                Divider().fontWeight(.bold).padding(2) // Warning
                                if state.error, state.insulinCalculated > 0 {
                                    VStack {
                                        Text("VARNING!").font(.callout).bold().foregroundColor(.orange)
                                            .padding(.bottom, 2)
                                            .padding(.top, 3)
                                        Text(alertString())
                                            .foregroundColor(.secondary)
                                            .italic()
                                        Divider().fontWeight(.bold).padding(2)
                                    }
                                } else if state.insulinCalculated > state.insulinRecommended {
                                    VStack {
                                        Text("VARNING!").font(.callout).bold().foregroundColor(.orange)
                                            .padding(.bottom, 2)
                                            .padding(.top, 3)
                                        Text(alertString())
                                            .foregroundColor(.secondary)
                                            .italic()
                                        Divider().fontWeight(.bold).padding(2)
                                    }
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 15)
                            .padding(.leading, 15)
                            .padding(.trailing, 15)
                        }

                        .font(.footnote)
                    }
                    .navigationTitle("Boluskalkylator")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        leading:
                        HStack {
                            Button(action: {
                                showInfo.toggle()
                            }) {
                                Image(systemName: "chevron.left").fontWeight(.semibold)
                                Text("Tillbaka")
                            }
                        }
                    )
                }
            }
        }

        var changed: Bool {
            ((meal.first?.carbs ?? 0) > 0) || ((meal.first?.fat ?? 0) > 0) || ((meal.first?.protein ?? 0) > 0)
        }

        var hasFatOrProtein: Bool {
            ((meal.first?.fat ?? 0) > 0) || ((meal.first?.protein ?? 0) > 0)
        }

        func carbssView() {
            let id_ = meal.first?.id ?? ""
            if fetch {
                keepForNextWiew = true
                state.backToCarbsView(complexEntry: fetch, id_)
            } else {
                state.showModal(for: .addCarbs(editMode: false))
            }
        }

        var mealEntries: some View {
            VStack {
                if let carbs = meal.first?.carbs, carbs > 0 {
                    HStack {
                        Text("Carbs")
                        Spacer()
                        Text(carbs.formatted())
                        Text("g")
                    }
                    .foregroundColor(.primary)
                    .padding(.bottom, 0.1)
                }
                if let fat = meal.first?.fat, fat > 0 {
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text(fat.formatted())
                        Text("g")
                    }
                    .foregroundColor(.brown)
                    .padding(.bottom, 0.1)
                }
                if let protein = meal.first?.protein, protein > 0 {
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text(protein.formatted())
                        Text("g")
                    }
                    .foregroundColor(.brown)
                    .padding(.bottom, 0.1)
                }
                if let note = meal.first?.note, note != "" {
                    HStack {
                        Text("Note")
                        Spacer()
                        Text(note)
                        Text("")
                    }
                }
            }
            .onTapGesture {
                let id_ = meal.first?.id ?? ""
                keepForNextWiew = true
                state.backToCarbsView(complexEntry: fetch, id_)
            }
        }

        /* private func alertString() -> String {
         switch state.errorString {
         case 1,
         2:
         return NSLocalizedString(
         "Eventual Glucose > Target Glucose, but glucose is predicted to first drop down to ",
         comment: "Bolus pop-up / Alert string. Make translations concise!"
         ) + state.minGuardBG
         .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) + " " +
         state.units
         .rawValue + ", " +
         NSLocalizedString(
         "which is below your Threshold (",
         comment: "Bolus pop-up / Alert string. Make translations concise!"
         ) + state
         .threshold
         .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) + ")"
         case 3:
         return NSLocalizedString(
         "Eventual Glucose > Target Glucose, but glucose is climbing slower than expected. Expected: ",
         comment: "Bolus pop-up / Alert string. Make translations concise!"
         ) +
         state.expectedDelta
         .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) +
         NSLocalizedString(". Climbing: ", comment: "Bolus pop-up / Alert string. Make translatons concise!") +
         state
         .minDelta.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))
         case 4:
         return NSLocalizedString(
         "Eventual Glucose > Target Glucose, but glucose is falling faster than expected. Expected: ",
         comment: "Bolus pop-up / Alert string. Make translations concise!"
         ) +
         state.expectedDelta
         .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) +
         NSLocalizedString(". Falling: ", comment: "Bolus pop-up / Alert string. Make translations concise!") +
         state
         .minDelta.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))
         case 5:
         return NSLocalizedString(
         "Eventual Glucose > Target Glucose, but glucose is changing faster than expected. Expected: ",
         comment: "Bolus pop-up / Alert string. Make translations concise!"
         ) +
         state.expectedDelta
         .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) +
         NSLocalizedString(". Changing: ", comment: "Bolus pop-up / Alert string. Make translations concise!") +
         state
         .minDelta.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))
         case 6:
         return NSLocalizedString(
         "Eventual Glucose > Target Glucose, but glucose is predicted to first drop down to ",
         comment: "Bolus pop-up / Alert string. Make translations concise!"
         ) + state
         .minPredBG
         .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) + " " +
         state
         .units
         .rawValue
         default:
         return "Ignore Warning..."*/

        private func alertString() -> String {
            switch state.errorString {
            case 1,
                 2:
                return NSLocalizedString(
                    "Boluskalkylatorns förslag på ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) + state.insulinCalculated
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(2))) + " E " +
                    NSLocalizedString(
                        "kan vara för starkt (utifrån nuvarande blodsockerkurva och trend)",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    )
            case 3:
                return NSLocalizedString(
                    "Boluskalkylatorns förslag på ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) + state.insulinCalculated
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(2))) + " E " +
                    NSLocalizedString(
                        "kan vara för starkt (utifrån nuvarande blodsockerkurva och trend)",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    )
            case 4:
                return NSLocalizedString(
                    "Boluskalkylatorns förslag på ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) + state.insulinCalculated
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(2))) + " E " +
                    NSLocalizedString(
                        "kan vara för starkt (utifrån nuvarande blodsockerkurva och trend)",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    )
            case 5:
                return NSLocalizedString(
                    "Boluskalkylatorns förslag på ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) + state.insulinCalculated
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(2))) + " E " +
                    NSLocalizedString(
                        "kan vara för starkt (utifrån nuvarande blodsockerkurva och trend)",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    )
            case 6:
                return NSLocalizedString(
                    "Boluskalkylatorns förslag på ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) + state.insulinCalculated
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(2))) + " E " +
                    NSLocalizedString(
                        "kan vara för starkt (utifrån nuvarande blodsockerkurva och trend)",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    )
            default:
                return NSLocalizedString(
                    "Boluskalkylatorns förslag på ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) + state.insulinCalculated
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(2))) + " E " +
                    NSLocalizedString(
                        "kan vara för starkt (utifrån nuvarande blodsockerkurva och trend)",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    )
            }
        }
    }
}
