import SwiftUI
import Swinject

extension BolusCalculatorConfig {
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

        var body: some View {
            Form {
                Section {
                    HStack {
                        Toggle("Använd ny boluskalkylator", isOn: $state.useCalc)
                    }
                    if state.useCalc {
                        HStack {
                            Toggle("Visa detaljerad data och beräkningar", isOn: $state.advancedCalc)
                        }
                        HStack {
                            Text("Manuell bolus faktor")
                            Spacer()
                            DecimalTextField("0.8", value: $state.overrideFactor, formatter: conversionFormatter)
                        }
                    }
                    if !state.useCalc {
                        HStack {
                            Text("Manuell bolus procent")
                            DecimalTextField("", value: $state.insulinReqPercentage, formatter: formatter)
                        }
                    }
                } header: { Text("Inställningar boluskalkylator") }

                if state.useCalc {
                    Section {
                        HStack {
                            Toggle("Använd faktor för fettrika måltider", isOn: $state.fattyMeals)
                        }
                        HStack {
                            Text("Justera bolus med faktor")
                            Spacer()
                            DecimalTextField("0.7", value: $state.fattyMealFactor, formatter: conversionFormatter)
                        }
                        HStack {
                            Text("Använd automatiskt om fett & protein i måltiden är mer än")
                            Spacer()
                            DecimalTextField("0.5", value: $state.fattyMealTrigger, formatter: conversionFormatter)
                        }
                    } header: { Text("Fett/proteinrika måltider") }
                }

                if state.useCalc {
                    Section {
                        HStack {
                            Toggle("Använd superbolus", isOn: $state.sweetMeals)
                        }
                        HStack {
                            Text("Antal timmar basal i superbolus")
                            Spacer()
                            DecimalTextField("2", value: $state.sweetMealFactor, formatter: conversionFormatter)
                        }
                    } header: { Text("Superbolus") }
                }

                Section(
                    footer: Text(
                        "Här kan du välja att använda den nya boluskalkylatorn istället för iAPS ordinarie bolusberäkningar. \n\nDen manuella bolusfaktorn (default 0.8) används för att begränsa hur stor andel av kalkylatorns totalt framräknade insulinbehov som ska rekommenderas  som bolus.\n\nFaktorn för fettrika måltider (default 0.7) lägger till ytterligare en begränsning till bolusrekommendationen för att ta hänsyn till en längre absorbtionstid.\n\n Därefter kan en faktor för vilken andel fett+protein i en registrerad måltid som ska trigga att faktorn för fettrika måltider aktiveras (default 0.5).\n\nAvslutningsvis kan möjligheten att ge superbolus aktiveras. Superbolusen ökar bolusberäkningen med schemalagd basal motsvarande det antal timmar som anges i inställningen för detta (default 2)"
                    )
                )
                    {}
            }
            .onAppear(perform: configureView)
            .navigationBarTitle("Boluskalkylator")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
