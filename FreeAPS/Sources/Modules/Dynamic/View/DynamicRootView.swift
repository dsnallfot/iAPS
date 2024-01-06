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

        @State private var infoButtonPressed: InfoText?

        var body: some View {
            Form {
                Section {
                    ZStack {
                        HStack {
                            Button("", action: {
                                infoButtonPressed = InfoText(
                                    description: NSLocalizedString(
                                        "Calculate a new ISF with every loop cycle. New ISF will be based on current BG, TDD of insulin (past 24 hours or a weighted average) and an Adjustment Factor (default is 1).\n\nDynamic ISF and CR ratios will be limited by your autosens.min/max limits.\n\nDynamic ratio replaces the autosens.ratio:\n\nNew ISF = Static ISF / Dynamic ratio,\n\nDynamic ratio = profile.sens * adjustmentFactor * tdd * Math.log(BG/insulinFactor+1) / 1800,\n\ninsulinFactor = 120 - InsulinPeakTimeInMinutes",
                                        comment: "Enable Dynamic ISF"
                                    ),
                                    oref0Variable: NSLocalizedString("Enable Dynamic ISF", comment: "")
                                )
                            })
                        }
                        Toggle("Aktivera dynamisk känslighet (ISF)", isOn: $state.useNewFormula)
                    }
                    if state.useNewFormula {
                        ZStack {
                            HStack {
                                Button("", action: {
                                    infoButtonPressed = InfoText(
                                        description: NSLocalizedString(
                                            "Use Dynamic CR. The dynamic ratio will be used for CR as follows:\n\n When ratio > 1:  dynCR = (newRatio - 1) / 2 + 1.\nWhen ratio < 1: dynCR = CR/dynCR.\n\nDon't use toghether with a high Insulin Fraction (> 2)",
                                            comment: "Enable Dynamic CR"
                                        ),
                                        oref0Variable: NSLocalizedString("Enable Dynamic CR", comment: "")
                                    )
                                })
                            }
                            Toggle("Aktivera dynamisk insulinkvot (CR)", isOn: $state.enableDynamicCR)
                        }
                    }
                } header: { Text("Enable") }

                if state.useNewFormula {
                    Section {
                        ZStack {
                            HStack {
                                Button("", action: {
                                    infoButtonPressed = InfoText(
                                        description: NSLocalizedString(
                                            "Use a sigmoid function for ISF (and for CR, when enabled), instead of the default Logarithmic formula. Requires the Dynamic ISF setting to be enabled in settings\n\nThe Adjustment setting adjusts the slope of the curve (Y: Dynamic ratio, X: Blood Glucose). A lower value ==> less steep == less aggressive.\n\nThe autosens.min/max settings determines both the max/min limits for the dynamic ratio AND how much the dynamic ratio is adjusted. If AF is the slope of the curve, the autosens.min/max is the height of the graph, the Y-interval, where Y: dynamic ratio. The curve will always have a sigmoid shape, no matter which autosens.min/max settings are used, meaning these settings have big consequences for the outcome of the computed dynamic ISF. Please be careful setting a too high autosens.max value. With a proper profile ISF setting, you will probably never need it to be higher than 1.5\n\nAn Autosens.max limit > 1.5 is not advisable when using the sigmoid function.",
                                            comment: "Use Sigmoid Function"
                                        ),
                                        oref0Variable: NSLocalizedString("Use Sigmoid Function", comment: "")
                                    )
                                })
                            }
                            Toggle("Använd Sigmoid formel", isOn: $state.sigmoid)
                        }
                    } header: { Text("Formel") }

                    Section {
                        ZStack {
                            HStack {
                                Button("", action: {
                                    infoButtonPressed = InfoText(
                                        description: NSLocalizedString(
                                            "Adjust Dynamic ratios by a constant. Default is 0.5. The higher the value, the larger the correction of your ISF will be for a high or a low BG. Maximum correction is determined by the Autosens min/max settings. For Sigmoid function an adjustment factor of 0.4 - 0.5 is recommended to begin with. For the logaritmic formula threre is less consensus, but starting with 0.5 - 0.8 is more appropiate for most users",
                                            comment: "Adjust Dynamic ISF constant"
                                        ),
                                        oref0Variable: NSLocalizedString("Adjust Dynamic ISF constant", comment: "")
                                    )
                                })
                            }
                            HStack {
                                Text("Adjust Dynamic ISF constant")
                                Spacer()
                                DecimalTextField("0", value: $state.adjustmentFactor, formatter: formatter)
                            }
                        }

                        ZStack {
                            HStack {
                                Button("", action: {
                                    infoButtonPressed = InfoText(
                                        description: NSLocalizedString(
                                            "Has to be > 0 and <= 1.\nDefault is 0.65 (65 %) * TDD. The rest will be from average of total data (up to 14 days) of all TDD calculations (35 %). To only use past 24 hours, set this to 1.\n\nTo avoid sudden fluctuations, for instance after a big meal, an average of the past 2 hours of TDD calculations is used instead of just the current TDD (past 24 hours at this moment).",
                                            comment: "Weighted Average of TDD. Weight of past 24 hours:"
                                        ),
                                        oref0Variable: NSLocalizedString(
                                            "Weighted Average of TDD. Weight of past 24 hours:",
                                            comment: ""
                                        )
                                    )
                                })
                            }
                            HStack {
                                Text("Weighted Average of TDD. Weight of past 24 hours:")
                                Spacer()
                                DecimalTextField("0", value: $state.weightPercentage, formatter: formatter)
                            }
                        }

                        ZStack {
                            HStack {
                                Button("", action: {
                                    infoButtonPressed = InfoText(
                                        description: NSLocalizedString(
                                            "Enable adjustment of basal based on the ratio of current TDD / 7 day average TDD",
                                            comment: "Adjust basal"
                                        ),
                                        oref0Variable: NSLocalizedString("Adjust basal", comment: "")
                                    )
                                })
                            }
                            Toggle("Adjust basal", isOn: $state.tddAdjBasal)
                        }
                    } header: { Text("Settings") }

                    Section {
                        ZStack {
                            HStack {
                                Button("", action: {
                                    infoButtonPressed = InfoText(
                                        description: NSLocalizedString(
                                            "The default threshold in FAX depends on your current minimum BG target, as follows:\n\nIf your minimum BG target = 90 mg/dl -> threshold = 65 mg/dl,\n\nif minimum BG target = 100 mg/dl -> threshold = 70 mg/dl,\n\nminimum BG target = 110 mg/dl -> threshold = 75 mg/dl,\n\nand if minimum BG target = 130 mg/dl  -> threshold = 85 mg/dl.\n\nThis setting allows you to change the default to a higher threshold for looping with dynISF. Valid values are 65 mg/dl<= Threshold Setting <= 120 mg/dl.",
                                            comment: "Threshold Setting (mg/dl)"
                                        ),
                                        oref0Variable: NSLocalizedString("Threshold Setting (mg/dl)", comment: "")
                                    )
                                })
                            }
                            HStack {
                                Text("Min BG tröskel")
                                Spacer()
                                DecimalTextField("0", value: $state.threshold_setting, formatter: glucoseFormatter)
                                Text(state.unit.rawValue)
                            }
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
            .alert(item: $infoButtonPressed) { infoButton in
                Alert(
                    title: Text("\(infoButton.oref0Variable)"),
                    message: Text("\(infoButton.description)"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}
