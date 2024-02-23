import SwiftUI
import Swinject

extension AutotuneConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State var replaceAlert = false

        private var isfFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var rateFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    Toggle("Use Autotune", isOn: $state.useAutotune)
                    if state.useAutotune {
                        Toggle("Använd endast Autotune för basal", isOn: $state.onlyAutotuneBasals)
                    }
                }

                Section {
                    HStack {
                        Text("Last run")
                        Spacer()
                        Text(dateFormatter.string(from: state.publishedDate))
                    }
                    Button {
                        let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                        impactHeavy.impactOccurred()
                        state.run() }
                    label: { Text("Run now") }
                }

                if let autotune = state.autotune {
                    if !state.onlyAutotuneBasals {
                        Section {
                            HStack {
                                Text("Carb ratio")
                                Spacer()
                                Text(isfFormatter.string(from: autotune.carbRatio as NSNumber) ?? "0")
                                Text("g/E").foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Sensitivity")
                                Spacer()
                                if state.units == .mmolL {
                                    Text(isfFormatter.string(from: autotune.sensitivity.asMmolL as NSNumber) ?? "0")
                                } else {
                                    Text(isfFormatter.string(from: autotune.sensitivity as NSNumber) ?? "0")
                                }
                                Text(state.units.rawValue + "/E").foregroundColor(.secondary)
                            }
                        }
                    }

                    Section(header: Text("Basal profile")) {
                        ForEach(0 ..< autotune.basalProfile.count, id: \.self) { index in
                            HStack {
                                Text(autotune.basalProfile[index].start).foregroundColor(.secondary)
                                Spacer()
                                Text(rateFormatter.string(from: autotune.basalProfile[index].rate as NSNumber) ?? "0")
                                Text("E/h").foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Text("Total")
                                .bold()
                                .foregroundColor(.primary)
                            Spacer()
                            Text(rateFormatter.string(from: autotune.basalProfile.reduce(0) { $0 + $1.rate } as NSNumber) ?? "0")
                                .foregroundColor(.primary) +
                                Text(" E/dag")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Button { state.delete() }
                        label: { Text("Delete autotune data")
                            .fontWeight(.semibold)
                            .tint(.white) }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color(.loopRed))
                    }

                    Section {
                        Button {
                            replaceAlert = true
                        }
                        label: { Text("Save as your Normal Basal Rates")
                            .fontWeight(.semibold)
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
                    } header: {
                        Text("Save on Pump")
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Autotune")
            .navigationBarTitleDisplayMode(.automatic)
            .alert(
                Text("Detta kommer att skriva över dina nuvarande basalinställningar \n\nÄr du säker på att du vill fortsätta?"),
                isPresented: $replaceAlert
            ) {
                Button("Cancel", action: {
                    replaceAlert.toggle()
                })
                Button("Spara", action: {
                    state.replace()
                    replaceAlert.toggle() })
            }
        }
    }
}
