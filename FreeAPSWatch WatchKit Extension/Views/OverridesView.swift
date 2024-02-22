import SwiftUI

struct OverridesView: View {
    @EnvironmentObject var state: WatchStateModel
    var body: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            state.enactOverride(id: "cancel")
        } label: {
            Text("Avsluta override")
        }.font(.headline.weight(.semibold))
            .padding(.bottom)
            .padding(.top)
            .tint(.loopRed)
        List {
            if state.overrides.isEmpty {
                Text("Spara en override på din iPhone först").padding()
            } else {
                ForEach(state.overrides) { override in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        state.enactOverride(id: override.id)
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(override.name)
                                if let until = override.until, until > Date.now {
                                    Spacer()
                                    if until > Date.now.addingTimeInterval(48.hours.timeInterval) {
                                        Text("∞").foregroundStyle(.purple)
                                    } else {
                                        Text(until, style: .timer).foregroundStyle(.purple)
                                    }
                                }
                            }
                            Text(override.description).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Overrides")
    }
}

struct OverridesView_Previews: PreviewProvider {
    static var previews: some View {
        let model = WatchStateModel()
        model.overrides = [
            OverridePresets_(
                name: "Custom",
                id: UUID().uuidString,
                until: Date().addingTimeInterval(60 * 60), description: "110 %"
            ),
            OverridePresets_(name: "Override 1", id: UUID().uuidString, until: nil, description: "120 %"),
            OverridePresets_(name: "Override 2", id: UUID().uuidString, until: nil, description: "6,5 mmol/l, 90 %")
        ]
        return OverridesView().environmentObject(model)
    }
}
