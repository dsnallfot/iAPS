import SwiftUI
import Swinject

extension Bolus {
    // alternative bolus calc
    struct AlternativeBolusCalcRootView: BaseView {
        let resolver: Resolver
        let waitForSuggestion: Bool
        @ObservedObject var state: StateModel

        @State private var showInfo = false
        @State private var carbsWarning = false
        @State var insulinCalculated: Decimal = 0
        @State private var displayError = false
        @State private var presentInfo = false

        @Environment(\.colorScheme) var colorScheme

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
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
                    if state.waitForSuggestion {
                        HStack {
                            Text("Wait please").foregroundColor(.secondary)
                            Spacer()
                            ActivityIndicator(isAnimating: .constant(true), style: .medium) // fix iOS 15 bug
                        }
                    } else {
                        HStack {
                            if state.error && state.insulinCalculated > 0 {
                                // Image(systemName: "exclamationmark.triangle.fill")
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .onTapGesture {
                                        showInfo.toggle()
                                    }
                                Text("Vänta med att ge bolus")
                                    .foregroundColor(.orange)
                                    .onTapGesture {
                                        showInfo.toggle()
                                    }
                            } else if state.insulinCalculated <= 0 {
                                // Image(systemName: "x.circle.fill")
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.red)
                                    .onTapGesture {
                                        showInfo.toggle()
                                    }
                                Text("Ingen bolus rekommenderas")
                                    .foregroundColor(.red)
                                    .onTapGesture {
                                        showInfo.toggle()
                                    }
                            } else {
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
                            }
                            Spacer()

                            if state.error && state.insulinCalculated > 0 {
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
                                ).foregroundColor(.red)
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
                                Text(!(state.amount > state.maxBolus * 3) ? "U" : "☠️").fontWeight(.semibold)
                            }
                        }
                    }
                }
                Section {
                    if !state.waitForSuggestion {
                        let maxamountbolus = Double(state.maxBolus)
                        let formattedMaxAmountBolus = String(maxamountbolus)

                        Button {
                            state.add()
                        } label: {
                            HStack {
                                if state.amount > state.maxBolus + 0.02 {
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(.red)
                                }

                                Text(
                                    !(state.amount > state.maxBolus + 0.02) ? "Ge bolusdos" :
                                        "Inställd maxgräns: \(formattedMaxAmountBolus)E   "
                                )
                                .font(.title3.weight(.semibold))
                            }
                        }
                        .disabled(
                            state.amount <= 0 || state.amount > state.maxBolus + 0.02
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                Section {
                    if waitForSuggestion {
                        Button { state.showModal(for: nil) }
                        label: { Text("Continue without bolus").font(.title3) }
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                // Transparent section to add space between enact bolus buttons and additional settings
                Section {
                    Text(" \n ")
                }
                .listRowBackground(Color.clear)
                Section(header: Text("Extra inställningar")) {
                    HStack {
                        if state.fattyMeals {
                            Text("Fettrik måltid?")
                                .foregroundColor(.brown)
                            // .font(.footnote)
                            Spacer()
                            Toggle(isOn: $state.useFattyMealCorrectionFactor) {}
                                .toggleStyle(CheckboxToggleStyle())
                                .foregroundColor(.brown)
                                // .font(.footnote)
                                .onChange(of: state.useFattyMealCorrectionFactor) { _ in
                                    insulinCalculated = state.calculateInsulin()
                                }
                        }
                    }
                    HStack {
                        Text("Blodsocker")
                        DecimalTextField(
                            "0",
                            value: Binding(
                                get: {
                                    if state.units == .mmolL {
                                        return state.currentBG.asMmolL
                                    } else {
                                        return state.currentBG
                                    }
                                },
                                set: { newValue in
                                    if state.units == .mmolL {
                                        state.currentBG = newValue.asMmolL
                                    } else {
                                        state.currentBG = newValue
                                    }
                                }
                            ),
                            formatter: glucoseFormatter,
                            autofocus: false,
                            cleanInput: true
                        )
                        .onChange(of: state.currentBG) { newValue in
                            if newValue > 500 {
                                state.currentBG = 500 // ensure that user can not input more than 500 mg/dL
                            }
                            insulinCalculated = state.calculateInsulin()
                        }
                        Text(state.units.rawValue)
                            .foregroundColor(.secondary)
                    }

                    // maybe remove this hstack or display entered carbs from carbs entry
                    HStack {
                        let maxamountcarbs = Double(state.maxCarbs)
                        let formattedMaxAmountCarbs = String(maxamountcarbs)
                        Text("Nya Kolhydrater \n(Utöver COB)")
                        Spacer()
                        DecimalTextField(
                            "0",
                            value: $state.enteredCarbs,
                            formatter: formatter,
                            autofocus: false,
                            cleanInput: true
                        )
                        .onChange(of: state.enteredCarbs) { newValue in
                            if newValue > state.maxCarbs {
                                state.enteredCarbs = state
                                    .maxCarbs // ensure that user can not input more than maxcarbs accidentally
                                carbsWarning.toggle()
                            }
                            insulinCalculated = state.calculateInsulin()
                        }
                        Text(
                            NSLocalizedString("g", comment: "grams")
                        )
                        .foregroundColor(.secondary)
                        .alert(
                            "Varning! \nInställd maxgräns är \(formattedMaxAmountCarbs)g kh!",
                            isPresented: $carbsWarning
                        ) {
                            Button("OK", role: .cancel) {}
                        }
                    }
                }
            }

            .navigationTitle("Enact Bolus")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
            // .blur(radius: showInfo ? 3 : 0)
            // .popup(isPresented: showInfo) {
            // bolusInfoAlternativeCalculator
            // }
            .onAppear {
                configureView {
                    state.waitForSuggestionInitial = waitForSuggestion
                    state.waitForSuggestion = waitForSuggestion
                }
            }
            .sheet(isPresented: $showInfo) {
                bolusInfoAlternativeCalculator
            }
        }

        // calculation showed in popup
        var bolusInfoAlternativeCalculator: some View {
            let unit = NSLocalizedString(
                " U",
                comment: "Unit in number of units delivered (keep the space character!)"
            )

            return VStack {
                VStack {
                    VStack(spacing: 3) {
                        HStack {
                            Text("Beräkningar")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 10)
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
                        .padding(.bottom, 3)
                        Divider()

                        HStack {
                            if abs(state.maxBolus - state.insulinCalculated) < 0.02 {
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
                        .padding(.top, 3)
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
                                Text("Inställd faktor fettrik måltid :")
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
                    Divider()
                    VStack(spacing: 3) {
                        HStack {
                            Text("Variabler").foregroundColor(.primary).fontWeight(.semibold)
                            Spacer()
                            Text("Behov +/-  E").foregroundColor(.primary).fontWeight(.semibold)
                        }
                        .padding(.top, 3)
                        .padding(.bottom, 3)
                        if state.enteredCarbs > 0 {
                            HStack(alignment: .center, spacing: nil) {
                                Text("Nya kolhydrater:")
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 105, alignment: .leading)

                                let carbs = state.enteredCarbs
                                Text(carbs.formatted())
                                    .frame(minWidth: 50, alignment: .trailing)

                                let unitGrams = NSLocalizedString("g", comment: "grams")
                                Text(unitGrams).foregroundColor(.secondary)
                                    .frame(minWidth: 50, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .frame(minWidth: 15, alignment: .trailing)
                                Spacer()
                                let insulinCarbs = state.enteredCarbs / state.carbRatio
                                // rounding
                                let insulinCarbsAsDouble = NSDecimalNumber(decimal: insulinCarbs).doubleValue
                                let roundedInsulinCarbs = Decimal(round(100 * insulinCarbsAsDouble) / 100)
                                Text(roundedInsulinCarbs.formatted())
                                Text(unit)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                            let insulinCob = state.wholeCobInsulin - state.enteredCarbs / state.carbRatio
                            // rounding
                            let insulinCobAsDouble = NSDecimalNumber(decimal: insulinCob).doubleValue
                            let roundedInsulinCob = Decimal(round(100 * insulinCobAsDouble) / 100)
                            Text(roundedInsulinCob.formatted())
                            Text(unit)
                                .foregroundColor(.secondary)
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
                    }

                    Divider()
                        .fontWeight(.bold)

                    HStack {
                        Text("Summa beräknat bolusbehov:")
                            .foregroundColor(.primary)
                        Spacer()
                        let insulin = state.roundedWholeCalc
                        Text(insulin.formatted())
                            .foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 5)
                    .padding(.bottom, 5)

                    Divider()
                        .fontWeight(.bold)

                    HStack {
                        if state.error && state.insulinCalculated > 0 {
                            Text("Vänta med bolus:")
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        } else if state.insulinCalculated <= 0 {
                            Text("Ingen bolus rek:")
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        } else {
                            Text("Förslag bolusdos:")
                                .fontWeight(.bold)
                                .foregroundColor(.green)
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
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                        } else if state.insulinCalculated <= 0 {
                            Text(roundedResult.formatted())
                                .fontWeight(.bold)
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            Text(unit)
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        } else {
                            Text(roundedResult.formatted())
                                .fontWeight(.bold)
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            Text(unit)
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                        }
                    }
                    .onTapGesture {
                        state.amount = state.insulinCalculated
                        showInfo.toggle()
                    }
                    // .padding(.leading, 16)
                    // .padding(.trailing, 16)
                    .padding(.top, 15)
                    .padding(.bottom, 5)
                    let maxamountbolus = Double(state.maxBolus)
                    let formattedMaxAmountBolus = String(maxamountbolus)
                    // if state.insulinCalculated == state.maxBolus {
                    if abs(state.maxBolus - state.insulinCalculated) < 0.02 {
                        Text("Obs! Förslaget begränsas av inställd maxbolus: \(formattedMaxAmountBolus) E")
                            // .font(.system(size: 12))
                            .foregroundColor(.purple).italic()
                    }
                    Divider()
                    // Warning
                    if state.error, state.insulinCalculated > 0 {
                        VStack {
                            Text("VARNING!").font(.callout).bold().foregroundColor(.orange)
                                .padding(.bottom, 3)
                            Text(alertString())
                                .foregroundColor(.secondary)
                                .italic()
                            Divider()
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 15)
                .padding(.leading, 16)
                .padding(.trailing, 16)

                // Hide sheet
                VStack {
                    Button { showInfo = false }
                    label: {
                        Text("OK")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.system(size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .font(.footnote)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(colorScheme == .dark ? UIColor.systemGray4 : UIColor.systemGray4).opacity(0))
            )
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
