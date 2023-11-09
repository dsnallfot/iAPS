import SwiftUI
import Swinject

extension Dynamic {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var conversionFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1

            return formatter
        }

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.unit == .mmolL {
                formatter.maximumFractionDigits = 1
            } else { formatter.maximumFractionDigits = 0 }
            formatter.roundingMode = .halfUp
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    HStack {
                        Toggle("Aktivera dynamisk känslighet(ISF)", isOn: $state.useNewFormula)
                    }
                    if state.useNewFormula {
                        HStack {
                            Toggle("Aktivera dynamisk insulinkvot(CR)", isOn: $state.enableDynamicCR)
                        }
                    }
                } header: { Text("Enable") }

                if state.useNewFormula {
                    Section {
                        HStack {
                            Toggle("Använd Sigmoid formel", isOn: $state.sigmoid)
                        }
                    } header: { Text("Formel") }

                    Section {
                        HStack {
                            Text("Adjustment Factor")
                            Spacer()
                            DecimalTextField("0", value: $state.adjustmentFactor, formatter: formatter)
                        }

                        HStack {
                            Text("Weighted Average of TDD. Weight of past 24 hours:")
                            Spacer()
                            DecimalTextField("0", value: $state.weightPercentage, formatter: formatter)
                        }

                        HStack {
                            Toggle("Adjust basal", isOn: $state.tddAdjBasal)
                        }
                    } header: { Text("Settings") }

                    Section {
                        HStack {
                            Text("Min BG tröskel")
                            Spacer()
                            DecimalTextField("0", value: $state.threshold_setting, formatter: glucoseFormatter)
                            Text(state.unit.rawValue)
                        }
                    } header: { Text("Säkerhet") }
                }
            }
            .onAppear(perform: configureView)
            .navigationBarTitle("Dynamisk ISF")
            .navigationBarTitleDisplayMode(.automatic)
            .onDisappear {
                state.saveIfChanged()
            }
        }
    }
}
