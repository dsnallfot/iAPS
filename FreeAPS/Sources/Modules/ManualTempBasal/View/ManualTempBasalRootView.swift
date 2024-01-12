import SwiftUI
import Swinject

extension ManualTempBasal {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    Button(action: state.cancel) {
                        HStack {
                            Image(systemName: "x.circle")
                                .tint(.loopRed)
                            Text("Avbryt temp basal")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .tint(.loopRed)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section {
                    HStack {
                        Text("Basaldos")
                        Spacer()
                        DecimalTextField("0,00", value: $state.rate, formatter: formatter, autofocus: true, cleanInput: true)
                        Text("E/h").foregroundColor(.secondary)
                    }
                    Picker(selection: $state.durationIndex, label: Text("Duration")) {
                        ForEach(0 ..< state.durationValues.count) { index in
                            Text(
                                String(
                                    format: "%.0f h %02.0f min",
                                    state.durationValues[index] / 60 - 0.1,
                                    state.durationValues[index].truncatingRemainder(dividingBy: 60)
                                )
                            ).tag(index)
                        }
                    }
                }

                Section {
                    let maxamountbasal = Double(state.maxBasal)
                    let formattedMaxAmountBasal = String(maxamountbasal)
                    Button { state.enact() }
                    label: {
                        HStack {
                            if state.rate > state.maxBasal {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.loopRed)
                            }

                            Text(
                                !(state.rate > state.maxBasal) ? "Aktivera temp basal" :
                                    "Inställd maxgräns: \(formattedMaxAmountBasal)E/h"
                            )
                            .fontWeight(.semibold)
                            .font(.title3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(state.rate <= 0 || state.rate > state.maxBasal)
                    .listRowBackground(
                        state.rate <= 0 || state.rate > state.maxBasal ? AnyView(Color(.systemGray4))
                            : AnyView(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                    Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                    Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                    Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                    Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .tint(.white)
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Manual Temp Basal")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
        }
    }
}
