import Charts
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
        // @State var insulinCalculated: Decimal = 0
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
                Section {
                    if fetch {
                        VStack {
                            if let carbs = meal.first?.carbs, carbs > 0 {
                                HStack {
                                    Text("Carbs")
                                    Spacer()
                                    Text(carbs.formatted())
                                    Text("g")
                                }
                                .foregroundColor(.primary)
                            }
                            if let fat = meal.first?.fat, fat > 0 {
                                HStack {
                                    Text("Fat")
                                    Spacer()
                                    Text(fat.formatted())
                                    Text("g")
                                }
                                .foregroundColor(.brown)
                            }
                            if let protein = meal.first?.protein, protein > 0 {
                                HStack {
                                    Text("Protein")
                                    Spacer()
                                    Text(protein.formatted())
                                    Text("g")
                                }
                                .foregroundColor(.brown)
                            }
                            if let note = meal.first?.note, note != "" {
                                HStack {
                                    Text("Note")
                                    Spacer()
                                    Text(note)
                                    Text("")
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .font(.subheadline)
                        HStack {
                            Button {
                                let id_ = meal.first?.id ?? ""
                                keepForNextWiew = true
                                state.backToCarbsView(complexEntry: fetch, id_)
                            }
                            label: {
                                // Image(systemName: "plus")
                                Text("Ändra måltid")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.subheadline)
                            .buttonStyle(BorderlessButtonStyle())
                            Spacer()
                            if state.fattyMeals {
                                Text("Hög fett/protein %")
                                    .foregroundColor(.brown)
                                    .font(.subheadline)

                                Toggle(isOn: $state.useFattyMealCorrectionFactor) {}
                                    .toggleStyle(CheckboxToggleStyle())
                                    .font(.subheadline)
                                    .foregroundColor(.brown)
                                    .onChange(of: state.useFattyMealCorrectionFactor) { _ in
                                        state.calculateInsulin() // Call the calculateInsulin function
                                    }
                            }
                        }

                    } else {
                        HStack {
                            Button {
                                state.showModal(for: .addCarbs(editMode: false))
                            }
                            label: {
                                // Image(systemName: "plus")
                                Text("Lägg till måltid")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .font(.title3)
                            .buttonStyle(BorderlessButtonStyle())
                            Spacer()
                        }
                    }
                }
                header: { Text("Aktuell måltid") }

                Section {
                    HStack {
                        if state.waitForSuggestion {
                            Image(systemName: "timer").foregroundColor(.secondary)
                            Text("Beräknar...").foregroundColor(.secondary)

                        } else if state.error && state.insulinCalculated > 0 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                // Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                    state.calculateInsulin() // Call the calculateInsulin function
                                }
                            Text("Vänta med att ge bolus")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                    state.calculateInsulin() // Call the calculateInsulin function
                                }
                        } else if state.insulinCalculated <= 0 {
                            Image(systemName: "x.circle.fill")
                                // Image(systemName: "info.circle.fill")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                    state.calculateInsulin() // Call the calculateInsulin function
                                }
                            Text("Ingen bolus rekommenderas")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                    state.calculateInsulin() // Call the calculateInsulin function
                                }
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                // Image(systemName: "info.circle.fill")
                                .foregroundColor(.green)
                                .onTapGesture {
                                    showInfo.toggle()
                                    state.calculateInsulin() // Call the calculateInsulin function
                                }
                            Text("Förslag bolusdos")
                                .foregroundColor(.green)
                                .onTapGesture {
                                    showInfo.toggle()
                                    state.calculateInsulin() // Call the calculateInsulin function
                                }
                        }
                        Spacer()

                        if state.waitForSuggestion {
                            ActivityIndicator(isAnimating: .constant(true), style: .medium)

                        } else if state.error && state.insulinCalculated > 0 {
                            // Visa önskat innehåll för "Vänta med att ge bolus"
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.orange)
                        } else if state.insulinCalculated <= 0 {
                            // Visa önskat innehåll för "Ingen bolus rekommenderas"
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.loopRed)
                        } else {
                            // Visa önskat innehåll för "Rekommenderad bolus"
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
                        } else if state.insulinCalculated <= 0 {
                            showInfo.toggle()
                            state.calculateInsulin() // Call the calculateInsulin function
                        } else {
                            state.amount = state.insulinCalculated
                        }
                    }
                    .alert(isPresented: $displayError) {
                        Alert(
                            title: Text("Varning!"),
                            message: Text("\n" + alertString() + "\n"),
                            primaryButton: .destructive(
                                Text("Add"),
                                action: {
                                    state.amount = state.insulinCalculated
                                    displayError = false
                                }
                            ),
                            secondaryButton: .cancel()
                        )
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
                } header: { Text("Bolusberäkning") }

                Section {
                    if state.amount > 0 {
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
                                Text(exceededMaxBolus ? "Inställd maxgräns: \(formattedMaxAmountBolus)E   " : "Ge bolusdos") }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .font(.title2.weight(.semibold))
                                .foregroundColor(exceededMaxBolus ? .loopRed : .accentColor)
                        }
                        .disabled(
                            state.amount <= 0 || state.amount > state.maxBolus
                        )
                    }
                }
                Section {
                    Button {
                        keepForNextWiew = true
                        state.showModal(for: nil)
                    }
                    label: { Text("Continue without bolus") }.frame(maxWidth: .infinity, alignment: .center)
                        .font(.title3)
                }
            }
            .navigationTitle("Enact Bolus")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button { state.hideModal() }
                label: { Text("Cancel") }
            )
            .navigationBarItems(
                trailing: Button(action: {
                    state.calculateInsulin() // Call the calculateInsulin function
                    showInfo.toggle()
                }) {
                    HStack {
                        Text("")
                        Image(systemName: "info.circle.fill")
                    }
                }
            )

            .onAppear {
                configureView {
                    state.waitForSuggestionInitial = waitForSuggestion
                    state.waitForSuggestion = waitForSuggestion
                    state.insulinCalculated = state.calculateInsulin()
                }
                // Additional code to automatically check the checkbox
                if let carbs = meal.first?.carbs,
                   let fat = meal.first?.fat,
                   let protein = meal.first?.protein
                {
                    let fatPercentage = (fat + protein) / (carbs + fat + protein)
                    if fatPercentage > 0.5 {
                        state.useFattyMealCorrectionFactor = true
                    }
                }
            }
            .onDisappear {
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

        var changed: Bool {
            ((meal.first?.carbs ?? 0) > 0) || ((meal.first?.fat ?? 0) > 0) || ((meal.first?.protein ?? 0) > 0)
        }

        var hasFatOrProtein: Bool {
            ((meal.first?.fat ?? 0) > 0) || ((meal.first?.protein ?? 0) > 0)
        }

        // calculation showed in sheet
        var bolusInfoAlternativeCalculator: some View {
            NavigationView {
                VStack {
                    let unit = NSLocalizedString(" U", comment: "Unit in number of units delivered (keep the space character!)")
                    VStack {
                        VStack {
                            VStack(spacing: 2) {
                                if fetch {
                                    VStack {
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
                                                Text(mealFormatter.string(from: fat as NSNumber) ?? "").foregroundColor(.brown)
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
                                    // Basal dont update for some reason. needs to check. not crucial info in the calc view however
                                    /* HStack {
                                         Text("Aktuell basal:")
                                             .foregroundColor(.secondary)
                                         Spacer()
                                         let basal = state.basal
                                         Text(basal.formatted())
                                         Text(NSLocalizedString("E/h", comment: " Units per hour"))
                                             .foregroundColor(.secondary)
                                     } */
                                    HStack {
                                        Text("Aktuell insulinkvot:")
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
                                        // if state.insulinRequired > 0 {
                                        Text("(Oref) Insulinbehov:")
                                            .foregroundColor(.secondary)
                                            .italic()
                                        Spacer()
                                        Text(state.insulinRequired.formatted())
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
                                        Text("Inställd max kolhydrater:")
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
                                            Text("Inställd faktor fet måltid :")
                                                .foregroundColor(.brown)
                                            Spacer()
                                            let fraction = state.fattyMealFactor * 100
                                            Text(fraction.formatted())
                                                .foregroundColor(.brown)
                                            Text("%")
                                                .foregroundColor(.brown)
                                        }
                                    }
                                }
                            }

                            Divider().fontWeight(.bold).padding(2)
                            VStack(spacing: 2) {
                                // Group {
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
                                            let insulinMealAsDouble = NSDecimalNumber(decimal: insulinMeal).doubleValue
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
                                    let targetDifferenceInsulinAsDouble = NSDecimalNumber(decimal: targetDifferenceInsulin)
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
                                let fraction = state.fraction * 100
                                Text(fraction.formatted())
                                Text("%  x ")
                                    .foregroundColor(.secondary)

                                // if fatty meal is chosen
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
                            .onTapGesture {
                                state.amount = state.insulinCalculated
                                showInfo.toggle()
                            }
                            .padding(.top, 2)

                            let maxamountbolus = Double(state.maxBolus)
                            let formattedMaxAmountBolus = String(maxamountbolus)
                            if state.insulinCalculated == state.maxBolus {
                                Text("Obs! Förslaget begränsas av inställd maxbolus: \(formattedMaxAmountBolus) E")
                                    // .font(.system(size: 12))
                                    .foregroundColor(.purple).italic()
                                    .padding(.top, 2)
                            }
                            Divider().fontWeight(.bold).padding(2) // Warning
                            if state.error, state.insulinCalculated > 0 {
                                VStack {
                                    Text("VARNING!").font(.callout).bold().foregroundColor(.orange)
                                        .padding(.bottom, 2)
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

                        // Hide sheet
                        /* VStack {
                              Button { showInfo = false }
                              label: {
                                  Text("OK")
                              }
                              .frame(maxWidth: .infinity, alignment: .center)
                              .font(.system(size: 20))
                              .fontWeight(.semibold)
                              .foregroundColor(.blue)
                          }
                         .padding(.top, 15)
                         .padding(.bottom, 15)*/
                    }

                    .font(.footnote)
                }
                .navigationTitle("Bolusberäkning")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(leading: Button("Tillbaka", action: { showInfo.toggle()
                }))
            }
        }

        private func alertString() -> String {
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
                return "Ignore Warning..."
            }
        }
    }
}
