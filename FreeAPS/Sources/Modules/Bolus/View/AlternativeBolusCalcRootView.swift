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

        var roundedOrefInsulin: Decimal {
            let insulinAsDouble = NSDecimalNumber(decimal: state.insulin).doubleValue
            let roundedInsulinAsDouble = (insulinAsDouble / 0.05).rounded() * 0.05
            return Decimal(roundedInsulinAsDouble)
        }

        var roundedMinBG: Decimal {
            let minBGAsDouble = NSDecimalNumber(decimal: state.minGuardBG).doubleValue
            let roundedMinBGAsDouble = (minBGAsDouble / 0.1).rounded() * 0.1
            return Decimal(roundedMinBGAsDouble)
        }

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
                    } header: { Text("Aktuell måltid") }
                }
                Section {
                    bolusSuggestion
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if state.insulinCalculated <= 0 || roundedOrefInsulin <= 0 {
                                showInfo.toggle()
                                state.insulinCalculated = state.calculateInsulin()
                            } else if state.error && state.insulinCalculated > 0 {
                                displayError = true
                            } else if state.insulinCalculated > roundedOrefInsulin && !state.useSuperBolus {
                                displayError = true
                            } else {
                                state.amount = state.insulinCalculated
                            }
                        }
                    if state.fattyMeals || state.sweetMeals {
                        checkboxParts
                    }
                } // header: { Text("Bolus") }

                Section {
                    // if !state.waitForSuggestion {
                    HStack {
                        Text("Ange bolusdos").fontWeight(.semibold)
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
                    .listRowBackground(Color(.insulin).opacity(1))
                    // }
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
                                Text(exceededMaxBolus ? "Inställd maxgräns: \(formattedMaxAmountBolus)E   " : "Ge bolusdos")
                                    .fontWeight(.semibold)
                                    .font(.title3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(state.amount <= 0 || state.amount > state.maxBolus)
                        .listRowBackground(
                            state.amount <= 0 || state.amount > state
                                .maxBolus ? Color(.systemGray4) : Color(.insulin)
                        )
                        .tint(.white)
                    }
                }
                if state.amount <= 0 {
                    Section {
                        Button {
                            keepForNextWiew = true
                            state.showModal(for: nil)
                        }
                        label: { Text("Continue without bolus") }.frame(maxWidth: .infinity, alignment: .center).font(.title3)
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
                            if state.insulinCalculated > roundedOrefInsulin {
                                if roundedOrefInsulin <= 0, !state.useSuperBolus {
                                    state.amount = 0
                                    displayError = false
                                } else if roundedOrefInsulin <= 0, state.useSuperBolus {
                                    state.amount = state.insulinCalculated
                                    displayError = false
                                } else if state.useSuperBolus {
                                    state.amount = state.insulinCalculated
                                    displayError = false
                                } else {
                                    state.amount = roundedOrefInsulin
                                    displayError = false
                                }
                            } else {
                                if state.insulinCalculated <= 0, !state.useSuperBolus {
                                    state.amount = 0
                                    displayError = false
                                } else if state.insulinCalculated <= 0, state.useSuperBolus {
                                    state.amount = state.insulinCalculated
                                    displayError = false
                                } else if state.useSuperBolus {
                                    state.amount = state.insulinCalculated
                                    displayError = false
                                } else {
                                    state.amount = state.insulinCalculated
                                    displayError = false
                                }
                            }
                        }
                    ),
                    secondaryButton: .cancel()
                )
            }

            .navigationBarTitle("Enact Bolus", displayMode: .inline)
            .navigationBarItems(
                leading: Button {
                    carbsView()
                }
                label: {
                    Image(systemName: "chevron.left")
                        .scaleEffect(0.61)
                        .font(Font.title.weight(.semibold))
                        .offset(x: -13, y: 0)

                    Text("Måltid")
                        .offset(x: -22, y: 0)
                },
                trailing: Button { state.hideModal() }
                label: { Text("Close") }
            )
            .onAppear {
                configureView {
                    state.waitForSuggestionInitial = waitForSuggestion
                    state.waitForSuggestion = waitForSuggestion
                    state.insulinCalculated = state.calculateInsulin()
                }
                // force update of calculations
                state.getCurrentBasal()
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
                    state.delete(deleteTwice: true, meal: meal)
                } else if fetch, !keepForNextWiew {
                    state.delete(deleteTwice: false, meal: meal)
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
                    VStack {
                        VStack {
                            VStack {
                                VStack {
                                    if fetch {
                                        mealParts
                                        if fetch {
                                            Divider().fontWeight(.bold) // .padding(1)
                                        }
                                    }

                                    VStack {
                                        variableParts

                                        Divider().fontWeight(.bold) // .padding(1)

                                        guardRailParts

                                        Divider().fontWeight(.bold) // .padding(1)
                                    }
                                    VStack {
                                        if state.advancedCalc {
                                            orefParts

                                            Divider().fontWeight(.bold) // .padding(1)
                                        }

                                        calculationParts

                                        Divider().fontWeight(.bold) // .padding(1)
                                    }
                                    VStack {
                                        HStack {
                                            Text("Summa beräknat bolusbehov:")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            let insulin = state.roundedWholeCalc
                                            Text(insulin.formatted())
                                                .foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                                            Text("E")
                                                .foregroundColor(.primary)
                                        }
                                        .fontWeight(.semibold)
                                        .padding(.top, 1)
                                        .padding(.bottom, 1)
                                    }
                                    Divider().fontWeight(.bold) // .padding(1)
                                    VStack {
                                        resultsPart

                                        warningParts
                                    }
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 10)
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
                                Image(systemName: "chevron.left")
                                    .scaleEffect(0.61)
                                    .font(Font.title.weight(.semibold))
                                    .offset(x: -13, y: 0)
                                Text("Tillbaka")
                                    .offset(x: -22, y: 0)
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

        func carbsView() {
            if fetch {
                keepForNextWiew = true
                state.backToCarbsView(complexEntry: true, meal, override: false)
            } else {
                state.backToCarbsView(complexEntry: false, meal, override: true)
            }
        }

        var mealEntries: some View {
            VStack {
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

                        .foregroundColor(.primary)
                        .padding(.bottom, 0.1)
                    }
                }
                VStack {
                    if let protein = meal.first?.protein, protein > 0 {
                        HStack {
                            Text("Protein")
                            Spacer()
                            Text(protein.formatted())
                            Text("g")
                        }
                        .foregroundColor(.primary)
                        .padding(.bottom, 0.1)
                    }
                    if let note = meal.first?.note, note != "" {
                        HStack {
                            Text("Note")
                            Spacer()
                            Text(note)
                        }
                    }
                }
            }
            .listRowBackground(Color(.loopYellow).opacity(0.8))
            .onTapGesture {
                keepForNextWiew = true
                state.backToCarbsView(complexEntry: true, meal, override: false)
            }
        }

        var checkboxParts: some View {
            VStack {
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
                            .offset(x: 3, y: 0)

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
                            .offset(x: 3, y: 0)

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

        var bolusSuggestion: some View {
            VStack {
                HStack {
                    if state.waitForSuggestion {
                        HStack {
                            Image(systemName: "timer").foregroundColor(.secondary)
                            Text("Beräknar...").foregroundColor(.secondary)
                            Spacer()
                            ActivityIndicator(isAnimating: .constant(true), style: .medium)
                        }
                    } else if state.insulinCalculated <= 0 && state.useSuperBolus || roundedOrefInsulin <= 0 && state
                        .useSuperBolus
                    {
                        HStack {
                            // Image(systemName: "x.circle.fill")
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Vänta med superbolus?")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.loopRed)
                        }
                    } else if state.insulinCalculated <= 0 || roundedOrefInsulin <= 0 {
                        HStack {
                            // Image(systemName: "x.circle.fill")
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Ingen bolus rekommenderas")
                                .foregroundColor(.loopRed)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.loopRed)
                        }
                    } else if state.insulinCalculated > roundedOrefInsulin && !state.useSuperBolus {
                        HStack {
                            // Image(systemName: "exclamationmark.triangle.fill")
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Vänta med att ge bolus?")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Spacer()
                            Text(
                                formatter
                                    .string(from: roundedOrefInsulin as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.orange)
                        }
                    } else if state.roundedWholeCalc > roundedOrefInsulin && state.useSuperBolus {
                        HStack {
                            // Image(systemName: "exclamationmark.triangle.fill")
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Vänta med superbolus?")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.orange)
                        }
                    } else if state.error && state.insulinCalculated > 0 {
                        HStack {
                            // Image(systemName: "exclamationmark.triangle.fill")
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Vänta med att ge bolus?")
                                .foregroundColor(.orange)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.orange)
                        }
                    } else if state.useSuperBolus {
                        HStack {
                            // Image(systemName: "checkmark.circle.fill")
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.cyan)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Superbolusdos")
                                .foregroundColor(.cyan)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.cyan)
                        }
                    } else {
                        HStack {
                            // Image(systemName: "checkmark.circle.fill")
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.green)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Text("Förslag bolusdos")
                                .foregroundColor(.green)
                                .onTapGesture {
                                    showInfo.toggle()
                                }
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinCalculated as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.green)
                        }
                    }
                }
            }
        }

        var mealParts: some View {
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
                if let carbs = meal.first?.carbs, carbs > 0 {
                    HStack {
                        Text("Beräknad effekt på blodsockret:")
                            .foregroundColor(.secondary)
                            .italic()
                        Spacer()

                        let carbImpact = Decimal(carbs) * state.isf / state.carbRatio

                        // Round csf to one decimal place using NSDecimalNumber
                        let roundedCarbImpact = NSDecimalNumber(decimal: carbImpact)
                            .rounding(accordingToBehavior: NSDecimalNumberHandler(
                                roundingMode: .plain,
                                scale: 1,
                                raiseOnExactness: false,
                                raiseOnOverflow: false,
                                raiseOnUnderflow: false,
                                raiseOnDivideByZero: false
                            ))

                        Text("+")
                        Text("\(roundedCarbImpact)").italic()

                        Text("mmol/L").foregroundColor(.secondary).italic()
                    }
                }
            }
        }

        var variableParts: some View {
            VStack(spacing: 2) {
                HStack {
                    Text("Variabler")
                        .fontWeight(.semibold)
                    Spacer()
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
                    Text("mmol/L")
                        .foregroundColor(.secondary)
                }
                // Basal dont update automatic for some reason, only when triggering save to pump. needs to check. not crucial info in the calc view right now
                HStack {
                    Text("Schemalagd basal:")
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
                HStack {
                    Text("Aktuell CSF (ökning per g kh):")
                        .foregroundColor(.secondary)
                    Spacer()

                    let csf = state.isf / state.carbRatio

                    // Round csf to one decimal place using NSDecimalNumber
                    let roundedCsf = NSDecimalNumber(decimal: csf).rounding(accordingToBehavior: NSDecimalNumberHandler(
                        roundingMode: .plain,
                        scale: 1,
                        raiseOnExactness: false,
                        raiseOnOverflow: false,
                        raiseOnUnderflow: false,
                        raiseOnDivideByZero: false
                    ))

                    Text("\(roundedCsf)")

                    Text(NSLocalizedString("mmol/L", comment: " grams per Unit"))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Aktuell ISF:")
                        .foregroundColor(.secondary)
                    Spacer()
                    let isf = state.isf
                    Text(isf.formatted())
                    Text("mmol/l/E")
                        .foregroundColor(.secondary)
                }
            }
        }

        var orefParts: some View {
            VStack(spacing: 2) {
                HStack {
                    Text("Prognos (oref)")
                        .fontWeight(.semibold)
                    Spacer()
                }
                HStack {
                    if state.evBG != 0 {
                        Text("Blodsockerprognos:")
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
                    if state.minGuardBG < state.threshold && state.minGuardBG != 0 {
                        Text("Lägsta förväntade BG:")
                            .foregroundColor(.loopRed)
                            .italic()
                        Spacer()
                        Text(roundedMinBG.formatted())
                            .foregroundColor(.loopRed)
                            .italic()
                        Text("mmol/L")
                            .foregroundColor(.loopRed)
                            .italic()
                    } else if state.minGuardBG != 0 {
                        Text("Lägsta förväntade BG:")
                            .foregroundColor(.secondary)
                            .italic()
                        Spacer()
                        Text(roundedMinBG.formatted())
                            .italic()
                        Text("mmol/L")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }

                HStack {
                    if state.insulinCalculated > roundedOrefInsulin && state
                        .insulinCalculated > 0 && roundedOrefInsulin > 0 && !state.useSuperBolus
                    {
                        Text("Insulinbehov:")
                            .foregroundColor(.insulin)
                            .italic()
                        Spacer()
                        Text(roundedOrefInsulin.formatted())
                            .foregroundColor(.insulin)
                            .italic()

                        Text(NSLocalizedString("E", comment: " grams per Unit"))
                            .foregroundColor(.insulin)
                            .italic()
                    } else if roundedOrefInsulin != 0 {
                        Text("Insulinbehov:")
                            .foregroundColor(.secondary)
                            .italic()
                        Spacer()
                        Text(roundedOrefInsulin.formatted())
                            .italic()

                        Text(NSLocalizedString("E", comment: " grams per Unit"))
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }

        var guardRailParts: some View {
            VStack(spacing: 2) {
                HStack {
                    if state.insulinCalculated >= state.maxBolus && state
                        .maxBolus <= (roundedOrefInsulin + state.superBolusInsulin)
                    {
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
                        .offset(x: 4, y: 0)
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
                            .offset(x: 4, y: 0)
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
                        Text("E")
                            .foregroundColor(.cyan)
                    }
                }
            }
        }

        var calculationParts: some View {
            VStack(spacing: 2) {
                HStack {
                    Text("Boluskalkyl")
                    Spacer()
                    Text("Behov +/-  E")
                }
                .foregroundColor(.primary).fontWeight(.semibold)
                .padding(.top, 2)
                .padding(.bottom, 2)

                let carbs = meal.first?.carbs
                let formattedCarbs = Decimal(carbs!)

                if fetch {
                    if let carbs = meal.first?.carbs, carbs > 0 {
                        HStack(alignment: .center, spacing: nil) {
                            Text("Aktuell måltid Kh:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 110, alignment: .leading)

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
                            Text("E")
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .center, spacing: nil) {
                            Text("COB:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 110, alignment: .leading)

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
                            Text("E")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(alignment: .center, spacing: nil) {
                        Text("COB:")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 110, alignment: .leading)

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
                        Text("E")
                            .foregroundColor(.secondary)
                    }
                }
                HStack(alignment: .center, spacing: nil) {
                    Text("IOB:")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 110, alignment: .leading)

                    let iob = state.iob
                    // rounding
                    let iobAsDouble = NSDecimalNumber(decimal: iob).doubleValue
                    let roundedIob = Decimal(round(100 * iobAsDouble) / 100)
                    Text(roundedIob.formatted())
                        .frame(minWidth: 50, alignment: .trailing)

                    Text("E")
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
                    Text("E").foregroundColor(.secondary)
                }
                HStack(alignment: .center, spacing: nil) {
                    Text("Blodsocker:")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 110, alignment: .leading)

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

                    Text("E")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .center, spacing: nil) {
                    Text("15 min trend:")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 110, alignment: .leading)

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
                    Text("E")
                        .foregroundColor(.secondary)
                }
            }
        }

        var resultsPart: some View {
            VStack {
                HStack {
                    if state.insulinCalculated <= 0 && !state.useSuperBolus || roundedOrefInsulin <= 0 && !state.useSuperBolus {
                        Text("Ingen bolus rek:")
                            .fontWeight(.bold)
                            .foregroundColor(.loopRed)
                            .font(.system(size: 16))
                    } else if state.error && state.insulinCalculated > 0 && !state.useSuperBolus {
                        Text("Vänta med bolus?")
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                    } else if state.insulinCalculated > roundedOrefInsulin && !state.useSuperBolus {
                        Text("Vänta med bolus?:")
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                    } else if state.useSuperBolus {
                        Text("Superbolus:")
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
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
                        HStack {
                            Text(fraction.formatted())
                            Text("%  x ")
                                .foregroundColor(.secondary)
                        }

                        if state.useFattyMealCorrectionFactor {
                            let fattyMealFactor = state.fattyMealFactor * 100
                            HStack {
                                Text(fattyMealFactor.formatted())
                                    .foregroundColor(.brown)
                                Text("%  x ")
                                    .foregroundColor(.secondary)
                            }
                        }
                        let insulin = state.roundedWholeCalc
                        HStack {
                            Text(insulin.formatted())
                                .foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                            Text(" E")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // roundedWholeCalc
                        let insulin = state.roundedWholeCalc
                        HStack {
                            Text(insulin.formatted())
                                .foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                            Text(" E")
                            // plus
                            Text(" + ")
                                .foregroundColor(.secondary)
                            // superBolusInsulin
                            let superBolusInsulin = state.superBolusInsulin
                            Text(superBolusInsulin.formatted())
                                .foregroundColor(.cyan)
                            Text(" E")
                                .foregroundColor(.cyan)
                        }
                    }
                    // Result calculations
                    if state.insulinCalculated > roundedOrefInsulin && !state.useSuperBolus {
                        if roundedOrefInsulin >= state.maxBolus {
                            Text(" ≠ ")
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            Button(action: {
                                state.amount = roundedOrefInsulin
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text(roundedOrefInsulin.formatted())
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.purple)
                                )
                            }
                        } else if roundedOrefInsulin <= 0 {
                            Text(" ≠ ")
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Button(action: {
                                state.amount = 0
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text("0")
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.loopRed)
                                )
                            }
                        } else {
                            Text(" ≠ ")
                                .fontWeight(.semibold)
                                .foregroundColor(.insulin)
                            Button(action: {
                                state.amount = roundedOrefInsulin
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text(roundedOrefInsulin.formatted())
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.insulin)
                                )
                            }
                        }
                    } else {
                        let result = state.insulinCalculated
                        let resultAsDouble = NSDecimalNumber(decimal: result).doubleValue
                        let roundedResult = (resultAsDouble / 0.05).rounded() * 0.05
                        if state.insulinCalculated >= state.maxBolus {
                            Text(" ≠ ")
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            Button(action: {
                                state.amount = Decimal(roundedResult)
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text(roundedResult.formatted())
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.purple)
                                )
                            }
                        } else if state.insulinCalculated <= 0 || roundedOrefInsulin <= 0 && !state.useSuperBolus {
                            Text(" ≠ ")
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Button(action: {
                                state.amount = 0
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text("0")
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.loopRed)
                                )
                            }
                        } else if state.error && state.insulinCalculated > 0 && !state.useSuperBolus {
                            Text(" = ")
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Button(action: {
                                state.amount = state.insulinCalculated
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text(state.insulinCalculated.formatted())
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.orange)
                                )
                            }
                        } else if state.useSuperBolus {
                            Text(" = ")
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Button(action: {
                                state.amount = state.insulinCalculated
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text(state.insulinCalculated.formatted())
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.cyan)
                                )
                            }
                        } else {
                            Text(" = ")
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Button(action: {
                                state.amount = Decimal(roundedResult)
                                showInfo.toggle()
                            }) {
                                HStack {
                                    Text(roundedResult.formatted())
                                        .fontWeight(.bold)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .offset(x: 5, y: 0)

                                    Text(" E")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                                .padding(.leading, 5)
                                .padding(.trailing, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                        .background(Color.green)
                                )
                            }
                        }
                    }
                }
            }
            // .padding(.top, 2)
            .padding(.bottom, 2)
        }

        var warningParts: some View {
            VStack {
                let maxamountbolus = Double(state.maxBolus)
                let formattedMaxAmountBolus = String(maxamountbolus)
                let orefamountbolus = Double(roundedOrefInsulin)
                let formattedOrefAmountBolus = String(format: "%.2f", orefamountbolus).replacingOccurrences(of: ".", with: ",")

                VStack {
                    if state.insulinCalculated > roundedOrefInsulin && state
                        .insulinCalculated > 0 && roundedOrefInsulin > 0 && !state.useSuperBolus
                    {
                        Text("Obs! Förslaget begränsas av insulinbehov (oref): \(formattedOrefAmountBolus) E")
                            .foregroundColor(.insulin).italic()
                            .padding(.top, 1)
                            .padding(.bottom, 2)
                    } else if state.insulinCalculated >= state.maxBolus {
                        Text("Obs! Förslaget begränsas av inställd maxbolus: \(formattedMaxAmountBolus) E")
                            .foregroundColor(.purple).italic()
                            .padding(.top, 1)
                            .padding(.bottom, 2)
                    }
                }
                Divider().fontWeight(.bold) // .padding(1)
                VStack {
                    if state.error, state.insulinCalculated > 0 {
                        VStack {
                            Text("VARNING!").font(.callout).bold().foregroundColor(.orange)
                                .padding(.bottom, 1)
                                .padding(.top, 2)
                            Text(alertString())
                                .foregroundColor(.secondary)
                                .italic()
                            Divider().fontWeight(.bold) // .padding(1)
                        }
                    } else if state.insulinCalculated > roundedOrefInsulin {
                        VStack {
                            Text("VARNING!").font(.callout).bold().foregroundColor(.orange)
                                .padding(.bottom, 1)
                                .padding(.top, 2)
                            Text(alertString())
                                .foregroundColor(.secondary)
                                .italic()
                            Divider().fontWeight(.bold) // .padding(1)
                        }
                    }
                }
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
                    .rawValue +
                    NSLocalizedString(
                        "which is below your Threshold (",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    ) + state
                    .threshold
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))
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
                return "Boluskalkylatorns förslag kan vara för aggressivt med hänsyn till nuvarande blodsockerkurva."

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

                /* private func alertString() -> String {
                 switch state.errorString {
                 case 1,
                 2:
                 return "Insulin behövs sannolikt inom kort men överväg att avvakta med doseringen till blodsockerkurvan"
                 case 3:
                 return ""
                 case 4:
                 return ""
                 case 5:
                 return ""
                 case 6:
                 return ""
                 default:
                 return "" */
            }
        }
    }
}
