import SwiftUI
import Swinject

extension BolusCalculatorConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @State var isPresented = false
        @State var description = Text("")
        @State var descriptionHeader = Text("")
        @State var confirm = false
        @State var graphics: (any View)?

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

                    Section {}
                    footer: { Text(
                        "Här kan du välja att använda den nya boluskalkylatorn istället för iAPS ordinarie bolusberäkningar. \n\nDen manuella bolusfaktorn (default 0.8) används för att begränsa hur stor andel av kalkylatorns totalt framräknade insulinbehov som ska rekommenderas  som bolus.\n\nFaktorn för fettrika måltider (default 0.7) lägger till ytterligare en begränsning till bolusrekommendationen för att ta hänsyn till en längre absorbtionstid.\n\n Därefter kan en faktor för vilken andel fett+protein i en registrerad måltid som ska trigga att faktorn för fettrika måltider aktiveras (default 0.5).\n\nAvslutningsvis kan möjligheten att ge superbolus aktiveras. Superbolusen ökar bolusberäkningen med schemalagd basal motsvarande det antal timmar som anges i inställningen för detta (default 2)"
                    )
                    }
                }
                Section {
                    HStack {
                        Toggle(isOn: $state.allowBolusShortcut) {
                            Text("Allow iOS Bolus Shortcuts").foregroundStyle(state.allowBolusShortcut ? .red : .primary)
                        }.disabled(isPresented)
                            ._onBindingChange($state.allowBolusShortcut, perform: { _ in
                                if state.allowBolusShortcut {
                                    confirm = true
                                    graphics = confirmButton()
                                    info(
                                        header: "Allow iOS Bolus Shortcuts",
                                        body: "If you enable this setting you will be able to use iOS shortcuts and its automations to trigger a bolus in iAPS.\n\nObserve that the iOS shortuts also works with Siri!\n\nIf you need to use Bolus Shorcuts, please make sure to turn off the listen for 'Hey Siri' setting in iPhone Siri settings, to avoid any inadvertant activaton of a bolus with Siri.\nIf you don't disable 'Hey Siri' the iAPS bolus shortcut can be triggered with the utterance 'Hey Siri, iAPS Bolus'.\n\nWhen triggered with Siri you will be asked for an amount and a confirmation before the bolus command can be sent to iAPS.",
                                        useGraphics: graphics
                                    )
                                }
                            })
                    }
                    if state.allowBolusShortcut {
                        HStack {
                            Text(
                                state.allowedRemoteBolusAmount > state.settingsManager.pumpSettings
                                    .maxBolus ? "Max Bolus exceeded!" :
                                    "Max allowed bolus amount using shortcuts "
                            )
                            .foregroundStyle(
                                state.allowedRemoteBolusAmount > state.settingsManager.pumpSettings
                                    .maxBolus ? .red : .primary
                            )
                            Spacer()
                            DecimalTextField("0", value: $state.allowedRemoteBolusAmount, formatter: conversionFormatter)
                        }
                    }
                } header: { Text("Allow iOS Bolus Shortcuts") }
            }
            .onAppear(perform: configureView)
            .navigationBarTitle("Boluskalkylator")
            .navigationBarTitleDisplayMode(.automatic)
            .blur(radius: isPresented ? 5 : 0)
            .description(isPresented: isPresented, alignment: .center) {
                if confirm { confirmationView() } else { infoView() }
            }
        }

        func info(header: String, body: String, useGraphics: (any View)?) {
            isPresented.toggle()
            description = Text(NSLocalizedString(body, comment: "Dynamic ISF Setting"))
            descriptionHeader = Text(NSLocalizedString(header, comment: "Dynamic ISF Setting Title"))
            graphics = useGraphics
        }

        var info: some View {
            VStack(spacing: 20) {
                descriptionHeader.font(.title2).bold()
                description.font(.body)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        func infoView() -> some View {
            info
                .formatDescription()
                .onTapGesture {
                    isPresented.toggle()
                }
        }

        func confirmationView() -> some View {
            ScrollView {
                VStack(spacing: 20) {
                    info
                    if let view = graphics {
                        view.asAny()
                    }
                }
                .formatDescription()
            }
        }

        @ViewBuilder func confirmButton() -> some View {
            HStack(spacing: 20) {
                Button("Enable") {
                    state.allowBolusShortcut = true
                    isPresented.toggle()
                    confirm = false
                }.buttonStyle(.borderedProminent).tint(.blue)

                Button("Cancel") {
                    state.allowBolusShortcut = false
                    isPresented.toggle()
                    confirm = false
                }.buttonStyle(.borderedProminent).tint(.red)
            }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
    }
}
