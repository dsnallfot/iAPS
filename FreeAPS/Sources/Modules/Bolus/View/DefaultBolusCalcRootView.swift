import SwiftUI
import Swinject

extension Bolus {
    struct DefaultBolusCalcRootView: BaseView {
        let resolver: Resolver
        let waitForSuggestion: Bool
        let fetch: Bool
        @StateObject var state = StateModel()

        @State private var presentInfo = false
        @State private var displayError = false

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
                            /* Image(systemName: "info.circle.fill").symbolRenderingMode(.palette).foregroundStyle(
                                 .primary, .blue
                             )
                             .onTapGesture {
                                 presentInfo.toggle()
                             } */

                            if state.error && state.insulinRecommended > 0 {
                                // Image(systemName: "exclamationmark.triangle.fill")
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .onTapGesture {
                                        presentInfo.toggle()
                                    }
                                Text("Vänta med att ge bolus")
                                    .foregroundColor(.orange)
                                    .onTapGesture {
                                        presentInfo.toggle()
                                    }
                            } else if state.insulinRecommended <= 0 {
                                // Image(systemName: "x.circle.fill")
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.loopRed)
                                    .onTapGesture {
                                        presentInfo.toggle()
                                    }
                                Text("Ingen bolus rekommenderas")
                                    .foregroundColor(.loopRed)
                                    .onTapGesture {
                                        presentInfo.toggle()
                                    }
                            } else {
                                // Image(systemName: "checkmark.circle.fill")
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.green)
                                    .onTapGesture {
                                        presentInfo.toggle()
                                    }
                                Text("Förslag bolusdos")
                                    .foregroundColor(.green)
                                    .onTapGesture {
                                        presentInfo.toggle()
                                    }
                            }
                            Spacer()

                            if state.error && state.insulinRecommended > 0 {
                                // Visa önskat innehåll för "Vänta med att ge bolus"
                                Text(
                                    formatter
                                        .string(from: state.insulinRecommended as NSNumber)! +
                                        NSLocalizedString(" U", comment: "Insulin unit")
                                ).foregroundColor(.orange)
                            } else if state.insulinRecommended <= 0 {
                                // Visa önskat innehåll för "Ingen bolus rekommenderas"
                                Text(
                                    formatter
                                        .string(from: state.insulinRecommended as NSNumber)! +
                                        NSLocalizedString(" U", comment: "Insulin unit")
                                ).foregroundColor(.loopRed)
                            } else {
                                // Visa önskat innehåll för "Rekommenderad bolus"
                                Text(
                                    formatter
                                        .string(from: state.insulinRecommended as NSNumber)! +
                                        NSLocalizedString(" U", comment: "Insulin unit")
                                ).foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if state.error, state.insulinRecommended > 0 {
                                displayError = true
                            } else if state.insulinRecommended <= 0 {
                                presentInfo.toggle()
                            } else {
                                state.amount = state.insulinRecommended
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
                                        .foregroundColor(.loopRed)
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
                    title: Text("Warning!"),
                    message: Text("\n" + alertString() + "\n"),
                    primaryButton: .destructive(
                        Text("Add"),
                        action: {
                            state.amount = state.insulinRecommended
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
            .popup(isPresented: presentInfo, alignment: .center, direction: .bottom) {
                bolusInfo
            }
        }

        var bolusInfo: some View {
            VStack {
                // Variables
                VStack(spacing: 3) {
                    HStack {
                        Text("Blodsockerprognos:").foregroundColor(.secondary)
                        let evg = state.units == .mmolL ? Decimal(state.evBG).asMmolL : Decimal(state.evBG)
                        Text(evg.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))))
                        Text(state.units.rawValue).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Målvärde glukos:").foregroundColor(.secondary)
                        let target = state.units == .mmolL ? state.target.asMmolL : state.target
                        Text(target.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))))
                        Text(state.units.rawValue).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Aktuell ISF:").foregroundColor(.secondary)
                        let isf = state.isf
                        Text(isf.formatted())
                        Text(state.units.rawValue + NSLocalizedString("/U", comment: "/Insulin unit"))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Inställd maxbolus:").foregroundColor(.secondary)
                        let MB = state.maxBolus
                        Text(MB.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))))
                        Text(NSLocalizedString("U", comment: "/Insulin unit"))
                            .foregroundColor(.secondary)
                    }
                    if state.percentage != 101 {
                        HStack {
                            Text("Inställd manuell bolusprocent:").foregroundColor(.secondary)
                            let percentage = state.percentage
                            Text(percentage.formatted())
                            Text("%").foregroundColor(.secondary)
                        }
                        .padding(.bottom, 4)
                    }
                    Divider()
                    HStack {
                        Text("Formula:")
                        Text("(Eventual Glucose - Target) / ISF")
                    }.foregroundColor(.secondary).italic().padding(.top, 4)
                    HStack {
                        let evg = state.units == .mmolL ? Decimal(state.evBG).asMmolL : Decimal(state.evBG)
                        let target = state.units == .mmolL ? state.target.asMmolL : state.target
                        let isf = state.isf
                        let result = (evg - target) / isf

                        Text(
                            "(\(evg.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits))))" +
                                " - \(target.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))))" +
                                " / \(isf.formatted()) ="
                        )
                        let fractionDigits: Int = 2 // Set the number of decimal places
                        Text(
                            "\(result.formatted(.number.grouping(.never).rounded().precision(.fractionLength(fractionDigits)))) E"
                        )
                    }

                    .foregroundColor(.secondary)
                    .italic()
                }
                .font(.footnote)
                .padding(.top, 4)
                Divider()
                // Formula
                VStack(spacing: 4) {
                    let unit = NSLocalizedString(
                        " U",
                        comment: "Unit in number of units delivered (keep the space character!)"
                    )
                    let color: Color = (state.percentage != 101 && state.insulin > 0) ? .secondary : .blue
                    let fontWeight: Font.Weight = (state.percentage != 101 && state.insulin > 0) ? .regular : .bold
                    HStack {
                        Text(NSLocalizedString("Totalt beräknat insulinbehov", comment: "") + ":")
                            .font(.callout).foregroundColor(.secondary)
                        Text(state.insulin.formatted() + unit).font(.callout).foregroundColor(color)
                            .fontWeight(fontWeight) // Daniel svensk anpassad översättning
                    }
                    .padding(.bottom, 4)
                    if state.percentage != 101, state.insulin > 0 {
                        Divider()
                        HStack {
                            Text(
                                "Förslag dos"
                            ).font(.callout).foregroundColor(.primary).bold()
                            Text(
                                "(" + state.percentage.formatted() + "% el. maxbolus) = "
                            )
                            .foregroundColor(.primary)
                            Text(
                                state.insulinRecommended.formatted() + unit
                            ).font(.callout).foregroundColor(.blue).bold()
                        }
                        .padding(.top, 4)
                    }
                }
                // Warning
                if state.error, state.insulinRecommended > 0 {
                    VStack(spacing: 4) {
                        Divider()
                        Text("VARNING!").font(.callout).bold().foregroundColor(.loopRed)
                        Text(alertString()).font(.footnote)
                        Divider()
                    }.padding(.horizontal, 10)
                }
                // Footer
                if !(state.error && state.insulinRecommended > 0) {
                    VStack {
                        Text(
                            "Carbs and previous insulin are included in the glucose prediction, but if the Eventual Glucose is lower than the Target Glucose, a bolus will not be recommended."
                        ).font(.caption2).foregroundColor(.secondary)
                    }.padding(20)
                }
                // Hide button
                VStack {
                    Button { presentInfo = false }
                    label: { Text("Hide") }.frame(maxWidth: .infinity, alignment: .center).font(.callout)
                        .foregroundColor(.blue)
                }.padding(.bottom, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(colorScheme == .dark ? UIColor.systemGray4 : UIColor.systemGray4))
            )
        }

        // Localize the Oref0 error/warning strings. The default should never be returned
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
