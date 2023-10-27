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
                                .tint(.red)
                            Text("Avbryt temp basal")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .tint(.red)
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
                                    .foregroundColor(.red)
                            }

                            Text(
                                !(state.rate > state.maxBasal) ? "Aktivera temp basal" :
                                    "Inställd maxgräns: \(formattedMaxAmountBasal)E/h"
                            )
                            .font(.title3.weight(.semibold))
                        }
                    }.disabled(
                        state.rate <= 0 || state.rate > state.maxBasal
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Manual Temp Basal")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
        }
    }
}
