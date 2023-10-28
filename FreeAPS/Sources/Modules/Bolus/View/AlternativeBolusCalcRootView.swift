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
                    }
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

                header: { Text("Bolus") }

                Section {
                    HStack {
                        Text("Blodsocker")
                        DecimalTextField(
                            "0",
                            value: Binding(
                                get: {
                                    if state.units == .mmolL {
                                        return state.currentBG * 0.0555
                                    } else {
                                        return state.currentBG
                                    }
                                },
                                set: { newValue in
                                    if state.units == .mmolL {
                                        state.currentBG = newValue * 0.0555
                                    } else {
                                        state.currentBG = newValue
                                    }
                                }
                            ),
                            formatter: formatter,
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
                    .contentShape(Rectangle())

//                   maybe remove this hstack or display entered carbs from carbs entry
                    HStack {
                        let maxamountcarbs = Double(state.maxCarbs)
                        let formattedMaxAmountCarbs = String(maxamountcarbs)
                        Text("Kolhydrater")
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
                        .alert("Varning! \nInställd maxgräns är \(formattedMaxAmountCarbs)g kh!", isPresented: $carbsWarning) {
                            Button("OK", role: .cancel) {}
                        }
                    }
                    HStack {
                        /* Button(action: {
                             showInfo.toggle()
                             insulinCalculated = state.calculateInsulin()
                         }, label: {
                             Image(systemName: "info.circle")
                             Text("Beräkningar")
                         })
                             .foregroundStyle(.blue)
                             .font(.footnote)
                             .buttonStyle(PlainButtonStyle())
                             .frame(maxWidth: .infinity, alignment: .leading)
                         Spacer()*/
                        if state.fattyMeals {
                            Text("Fettrik måltid?")
                            // .font(.footnote)
                            Spacer()
                            Toggle(isOn: $state.useFattyMealCorrectionFactor) {}
                                .toggleStyle(CheckboxToggleStyle())
                                // .font(.footnote)
                                .onChange(of: state.useFattyMealCorrectionFactor) { _ in
                                    insulinCalculated = state.calculateInsulin()
                                }
                        }
                    }
                }
                header: { Text("Detaljer") }

                if !state.waitForSuggestion {
                    Section {
                        let maxamountbolus = Double(state.maxBolus)
                        let formattedMaxAmountBolus = String(maxamountbolus)

                        Button {
                            state.add()
                        } label: {
                            HStack {
                                if state.amount > state.maxBolus {
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(.red)
                                }

                                Text(
                                    !(state.amount > state.maxBolus) ? "Ge bolusdos" :
                                        "Inställd maxgräns: \(formattedMaxAmountBolus)E   "
                                )
                                .font(.title3.weight(.semibold))
                            }
                        }
                        .disabled(
                            state.amount <= 0 || state.amount > state.maxBolus
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Section {
                        if waitForSuggestion {
                            Button { state.showModal(for: nil) }
                            label: { Text("Continue without bolus").font(.title3) }
                                .frame(maxWidth: .infinity, alignment: .center)
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
                            state.amount = state.insulinCalculated
                            displayError = false
                        }
                    ),
                    secondaryButton: .cancel()
                )
            }.onAppear {
                configureView {
                    state.waitForSuggestionInitial = waitForSuggestion
                    state.waitForSuggestion = waitForSuggestion
                }
            }
            .navigationTitle("Enact Bolus")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
            .blur(radius: showInfo ? 3 : 0)
            .popup(isPresented: showInfo) {
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
                    VStack {
                        HStack {
                            Text("Beräkningar")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        HStack {
                            Text("Insulinkvot enligt schema:")
                                .foregroundColor(.secondary)
                            Spacer()

                            Text(state.carbRatio.formatted())
                            Text(NSLocalizedString(" g/E", comment: " grams per Unit"))
                                .foregroundColor(.secondary)
                        }
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
                            Text(target.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))))
                            Text(state.units.rawValue)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Aktuell Basal:")
                                .foregroundColor(.secondary)
                            Spacer()
                            let basal = state.basal
                            Text(basal.formatted())
                            Text(NSLocalizedString("E/h", comment: " Units per hour"))
                                .foregroundColor(.secondary)
                        }
                        Divider()

                        HStack {
                            Text("Inställd maxbolus:")
                                .foregroundColor(.secondary)
                            Spacer()
                            let maxBolus = state.maxBolus
                            Text(maxBolus.formatted())
                            Text(NSLocalizedString("E", comment: " Units"))
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Inställd max kh:")
                                .foregroundColor(.secondary)
                            Spacer()
                            let maxCarbs = state.maxCarbs
                            Text(maxCarbs.formatted())
                            Text(NSLocalizedString("g", comment: "grams"))
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Inställd faktor dosering av totalt behov:")
                                .foregroundColor(.secondary)
                            Spacer()
                            let fraction = state.fraction
                            Text(fraction.formatted())
                        }
                        if state.useFattyMealCorrectionFactor {
                            HStack {
                                Text("Inställd faktor för fettrik måltid:")
                                    .foregroundColor(.orange)
                                Spacer()
                                let fraction = state.fattyMealFactor
                                Text(fraction.formatted())
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    Divider()
                    VStack {
                        HStack(alignment: .center, spacing: nil) {
                            Text("Blodsocker:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 95, maxHeight: 10, alignment: .leading)

                            let glucose = state.units == .mmolL ? state.currentBG.asMmolL : state.currentBG
                            Text(glucose.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))))
                                .frame(minWidth: 50, maxHeight: 10, alignment: .trailing)
                            Text(state.units.rawValue)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 50, maxHeight: 10, alignment: .leading)

                            Image(systemName: "arrow.right")
                                .frame(minWidth: 20, maxHeight: 10, alignment: .trailing)
                            Spacer()
                            let targetDifferenceInsulin = state.targetDifferenceInsulin
                            // rounding
                            let targetDifferenceInsulinAsDouble = NSDecimalNumber(decimal: targetDifferenceInsulin).doubleValue
                            let roundedTargetDifferenceInsulin = Decimal(round(100 * targetDifferenceInsulinAsDouble) / 100)

                            Text(roundedTargetDifferenceInsulin.formatted())

                            Text(unit)

                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .center, spacing: nil) {
                            Text("IOB:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 95, maxHeight: 10, alignment: .leading)

                            let iob = state.iob
                            // rounding
                            let iobAsDouble = NSDecimalNumber(decimal: iob).doubleValue
                            let roundedIob = Decimal(round(100 * iobAsDouble) / 100)
                            Text(roundedIob.formatted())
                                .frame(minWidth: 50, maxHeight: 10, alignment: .trailing)

                            Text(unit)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 50, maxHeight: 10, alignment: .leading)

                            Image(systemName: "arrow.right")
                                .frame(minWidth: 20, maxHeight: 10, alignment: .trailing)
                            Spacer()
                            let iobCalc = state.iobInsulinReduction
                            // rounding
                            let iobCalcAsDouble = NSDecimalNumber(decimal: iobCalc).doubleValue
                            let roundedIobCalc = Decimal(round(100 * iobCalcAsDouble) / 100)
                            Text(roundedIobCalc.formatted())
                            Text(unit).foregroundColor(.secondary)
                        }
                        HStack(alignment: .center, spacing: nil) {
                            Text("15 min trend:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 95, maxHeight: 10, alignment: .leading)

                            let trend = state.units == .mmolL ? state.deltaBG.asMmolL : state.deltaBG
                            Text(trend.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))))
                                .frame(minWidth: 50, maxHeight: 10, alignment: .trailing)
                            Text(state.units.rawValue).foregroundColor(.secondary)
                                .frame(minWidth: 50, maxHeight: 10, alignment: .leading)

                            Image(systemName: "arrow.right")
                                .frame(minWidth: 20, maxHeight: 10, alignment: .trailing)
                            Spacer()
                            let trendInsulin = state.fifteenMinInsulin
                            // rounding
                            let trendInsulinAsDouble = NSDecimalNumber(decimal: trendInsulin).doubleValue
                            let roundedTrendInsulin = Decimal(round(100 * trendInsulinAsDouble) / 100)
                            Text(roundedTrendInsulin.formatted())
                            Text(unit)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .center, spacing: nil) {
                            Text("COB + nya kh:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 95, maxHeight: 10, alignment: .leading)

                            let cob = state.cob
                            Text(cob.formatted())
                                .frame(minWidth: 50, maxHeight: 10, alignment: .trailing)

                            let unitGrams = NSLocalizedString("g", comment: "grams")
                            Text(unitGrams).foregroundColor(.secondary)
                                .frame(minWidth: 50, maxHeight: 10, alignment: .leading)

                            Image(systemName: "arrow.right")
                                .frame(minWidth: 20, maxHeight: 10, alignment: .trailing)
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
                    .padding()

                    Divider()
                        .fontWeight(.bold)

                    HStack {
                        Text("Totalt beräknat insulinbehov:")
                            .foregroundColor(.secondary)
                        Spacer()
                        let insulin = state.roundedWholeCalc
                        Text(insulin.formatted()).foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    Divider()
                        .fontWeight(.bold)

                    HStack {
                        Text("Förslag bolusdos:")
                            .fontWeight(.bold)
                        Spacer()
                        let fraction = state.fraction
                        Text(fraction.formatted())
                        Text(" x ")
                            .foregroundColor(.secondary)

                        // if fatty meal is chosen
                        if state.useFattyMealCorrectionFactor {
                            let fattyMealFactor = state.fattyMealFactor
                            Text(fattyMealFactor.formatted())
                                .foregroundColor(.orange)
                            Text(" x ")
                                .foregroundColor(.secondary)
                        }

                        let insulin = state.roundedWholeCalc
                        Text(insulin.formatted()).foregroundStyle(state.roundedWholeCalc < 0 ? Color.loopRed : Color.primary)
                        Text(unit)
                            .foregroundColor(.secondary)
                        Text(" = ")
                            .foregroundColor(.secondary)

                        let result = state.insulinCalculated
                        // rounding
                        let resultAsDouble = NSDecimalNumber(decimal: result).doubleValue
                        let roundedResult = (resultAsDouble / 0.05).rounded() * 0.05
                        Text(roundedResult.formatted())
                            .fontWeight(.bold)
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        state.amount = state.insulinCalculated
                        showInfo.toggle()
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.bottom, 5)
                    let maxamountbolus = Double(state.maxBolus)
                    let formattedMaxAmountBolus = String(maxamountbolus)
                    Text("Obs! Förslaget kan inte överskrida inställd maxbolus \(formattedMaxAmountBolus)E")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary).italic()
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                }
                .padding(.top, 10)
                .padding(.bottom, 15)

                // Hide button
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
                .padding(.bottom, 20)
            }
            .font(.footnote)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(colorScheme == .dark ? UIColor.systemGray4 : UIColor.systemGray4).opacity(0.9))
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
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) + " " + state.units
                    .rawValue + ", " +
                    NSLocalizedString(
                        "which is below your Threshold (",
                        comment: "Bolus pop-up / Alert string. Make translations concise!"
                    ) + state
                    .threshold.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) + ")"
            case 3:
                return NSLocalizedString(
                    "Eventual Glucose > Target Glucose, but glucose is climbing slower than expected. Expected: ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) +
                    state.expectedDelta
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) +
                    NSLocalizedString(". Climbing: ", comment: "Bolus pop-up / Alert string. Make translatons concise!") + state
                    .minDelta.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))
            case 4:
                return NSLocalizedString(
                    "Eventual Glucose > Target Glucose, but glucose is falling faster than expected. Expected: ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) +
                    state.expectedDelta
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) +
                    NSLocalizedString(". Falling: ", comment: "Bolus pop-up / Alert string. Make translations concise!") + state
                    .minDelta.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))
            case 5:
                return NSLocalizedString(
                    "Eventual Glucose > Target Glucose, but glucose is changing faster than expected. Expected: ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) +
                    state.expectedDelta
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) +
                    NSLocalizedString(". Changing: ", comment: "Bolus pop-up / Alert string. Make translations concise!") + state
                    .minDelta.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))
            case 6:
                return NSLocalizedString(
                    "Eventual Glucose > Target Glucose, but glucose is predicted to first drop down to ",
                    comment: "Bolus pop-up / Alert string. Make translations concise!"
                ) + state
                    .minPredBG
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))) + " " + state
                    .units
                    .rawValue
            default:
                return "Ignore Warning..."
            }
        }
    }
}
