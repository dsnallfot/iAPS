import SwiftUI
import Swinject

extension PumpSettingsEditor {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        var body: some View {
            Form {
                Section(header: Text("Delivery limits")) {
                    HStack {
                        Text("Max Basal")
                        DecimalTextField("U/hr", value: $state.maxBasal, formatter: formatter)
                    }
                    HStack {
                        Text("Max Bolus")
                        DecimalTextField("U", value: $state.maxBolus, formatter: formatter)
                    }
                    HStack {
                        Text("Max Carbs")
                        DecimalTextField("g", value: $state.maxCarbs, formatter: formatter)
                    }
                }

                Section(header: Text("Duration of Insulin Action")) {
                    HStack {
                        Text("DIA")
                        DecimalTextField("hours", value: $state.dia, formatter: formatter)
                    }
                }

                Section {
                    HStack {
                        if state.syncInProgress {
                            ProgressView().padding(.trailing, 10)
                        }
                        Button {
                            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                            impactHeavy.impactOccurred()
                            state.save() }
                        label: {
                            Text(state.syncInProgress ? "Saving..." : "Save on Pump")
                                .fontWeight(.semibold)
                                .font(.title3)
                        }
                        .disabled(state.syncInProgress)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(
                        AnyView(LinearGradient(
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
            .navigationTitle("Pumpinställningar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
