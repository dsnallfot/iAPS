import CoreData
import SwiftDate
import SwiftUI
import Swinject

extension AddTempTarget {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var isPromptPresented = false
        @State private var isRemoveAlertPresented = false
        @State private var removeAlert: Alert?
        @State private var isEditing = false
        @State private var selectedPreset: TempTarget?
        @State private var isEditSheetPresented = false

        @FetchRequest(
            entity: TempTargetsSlider.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var isEnabledArray: FetchedResults<TempTargetsSlider>

        @State private var originalPresetName: String = ""
        @State private var originalSettings: [String: Decimal] = [:]
        @State private var originalPercentage: Double = 100

        private var hasChanges: Bool {
            guard let originalLow = originalSettings["low"],
                  let originalDuration = originalSettings["duration"]
            else {
                return false
            }
            return state.newPresetName != originalPresetName || state.low != originalLow || state
                .duration != originalDuration || state.percentage != originalPercentage
        }

        private var buttonTitle: String {
            hasChanges ? "Spara ändringar" : "Inga ändringar"
        }

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var displayString: String {
            guard let preset = selectedPreset else { return "" }
            var low = preset.targetBottom
            if state.units == .mmolL {
                low = low?.asMmolL
            }

            let formattedLow = low.flatMap { formatter.string(from: $0 as NSNumber) } ?? ""
            let formattedDuration = formatter.string(from: preset.duration as NSNumber) ?? ""

            return "\(formattedLow) \(state.units.rawValue) i \(formattedDuration) min"
        }

        var body: some View {
            Form {
                if state.tempTarget != nil {
                    Section {
                        Button { state.cancel() }
                        label: {
                            HStack {
                                Image(systemName: "x.circle")
                                    .tint(.white)
                                Text("Avsluta tillfälligt mål")
                                    .fontWeight(.semibold)
                                    .font(.title3)
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color(.loopRed))
                    }
                }
                if !state.presets.isEmpty {
                    Section(header: Text("Aktivera favorit")) {
                        ForEach(state.presets) { preset in
                            presetView(for: preset)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .none, action: {
                                        removeAlert = Alert(
                                            title: Text("Are you sure?"),
                                            message: Text("Radera tillfälligt mål \n\(preset.displayName)?"),
                                            primaryButton: .destructive(Text("Delete"), action: {
                                                state.removePreset(id: preset.id)
                                                isRemoveAlertPresented = false // Dismiss the alert after deletion
                                            }),
                                            secondaryButton: .cancel()
                                        )
                                        isRemoveAlertPresented = true
                                    }) {
                                        Label("Ta bort", systemImage: "trash")
                                    }.tint(.red)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        selectedPreset = preset
                                        state.newPresetName = preset.displayName
                                        state.low = state.units == .mmolL ? preset.targetBottom?.asMmolL ?? 0 : preset
                                            .targetBottom ?? 0
                                        state.duration = preset.duration
                                        state.date = preset.date as? Date ?? Date()
                                        isEditSheetPresented = true
                                    } label: {
                                        Label("Redigera", systemImage: "square.and.pencil")
                                    }
                                    .tint(.blue)
                                }
                                .alert(isPresented: $isRemoveAlertPresented) {
                                    removeAlert!
                                }
                        }
                    }
                }
                settingsSection(header: "Custom")

                DatePicker("Date", selection: $state.date)

                HStack {
                    Button { state.enact() }
                    label: { Text("Aktivera tillfälligt mål") }
                        .disabled(state.duration == 0)
                        .controlSize(.mini)
                        .buttonStyle(BorderlessButtonStyle())
                    Spacer()
                    Button { isPromptPresented = true }
                    label: { Text("Spara ny favorit") }
                        .disabled(state.duration == 0)
                        .controlSize(.mini)
                        .buttonStyle(BorderlessButtonStyle())
                }
            }
            .popover(isPresented: $isPromptPresented) {
                NavigationView {
                    Form {
                        Section(header: Text("Ange namn på favorit")) {
                            TextField("Name", text: $state.newPresetName)
                        }
                        Section {
                            HStack {
                                Spacer()
                                Button {
                                    state.save()
                                    isPromptPresented = false
                                }
                                label: { Text("Save")
                                    .fontWeight(.semibold)
                                    .font(.title3)
                                }
                                Spacer()
                            }
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
                    .navigationTitle("Spara favorit")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button("Cancel", action: {
                        isPromptPresented = false
                    }))
                }
            }
            .sheet(isPresented: $isEditSheetPresented) {
                editPresetPopover()
            }
            .onAppear {
                configureView()
                state.hbt = isEnabledArray.first?.hbt ?? 160
            }
            .navigationTitle("Tillfälliga mål")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
        }

        @ViewBuilder func settingsSection(header: String) -> some View {
            HStack {
                Text("Använd HBT %")
                Toggle(isOn: $state.viewPercantage) {}
                    .controlSize(.mini)
                    .onChange(of: state.viewPercantage) { newValue in
                        if newValue {
                            guard let selectedPreset = selectedPreset,
                                  let targetBottom = selectedPreset.targetBottom else { return }
                            let computedPercentage = state.computePercentage(target: targetBottom)
                            state.percentage = Double(truncating: computedPercentage as NSNumber)
                        }
                    }
            }
            if state.viewPercantage {
                Section {
                    VStack {
                        Text("\(state.percentage.formatted(.number)) % Insulin")
                            .foregroundColor(isEditing ? .orange : .blue)
                            .font(.largeTitle)
                            .padding(.vertical)
                        Spacer()
                        Slider(
                            value: $state.percentage,
                            in: 15 ... min(Double(state.maxValue * 100), 200),
                            step: 1,
                            onEditingChanged: { editing in
                                isEditing = editing
                            }
                        )

                        // Only display target slider when not 100 %
                        if state.percentage != 100 {
                            Spacer()
                            Divider()
                            Text(
                                (
                                    state.units == .mmolL ?
                                        "\(state.computeTarget().asMmolL.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))) mmol/L" :
                                        "\(state.computeTarget().formatted(.number.grouping(.never).rounded().precision(.fractionLength(0)))) mg/dl"
                                )
                                    + NSLocalizedString("  Målvärde", comment: "")
                            )
                            .foregroundColor(.green)
                            .padding(.vertical)

                            Slider(
                                value: $state.hbt,
                                in: 101 ... 295,
                                step: 1
                            ).accentColor(.green)
                        }
                    }
                } footer: {
                    Text(
                        "Målvärdet justeras automatiskt utifrån den procentuella insulintillförseln du anger. \nBeräkningen utgår från oref0 algoritm för HBT 'Halvera basaldosen vid tillfälligt målvärde 160 mg/dl (8.9 mmol/L)'"
                    )
                }
            } else {
                Section(header: Text(header)) {
                    HStack {
                        Text("Target")
                        Spacer()
                        DecimalTextField("0", value: $state.low, formatter: formatter, cleanInput: true)
                        Text(state.units.rawValue).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: true)
                        Text("minutes").foregroundColor(.secondary)
                    }
                }
            }
            if state.viewPercantage {
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: true)
                        Text("minutes").foregroundColor(.secondary)
                    }
                }
            }
        }

        @ViewBuilder private func editPresetPopover() -> some View {
            NavigationView {
                Form {
                    Section(header: Text("Nytt namn")) {
                        TextField("Namn", text: $state.newPresetName)
                        Text("Nuvarande inställningar: \(displayString)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    settingsSection(header: "Nytt mål och varaktighet")
                    Section {
                        HStack {
                            Spacer()
                            Button {
                                guard let selectedPreset = selectedPreset else { return }
                                state.updatePreset(selectedPreset)
                                isEditSheetPresented = false
                            }
                            label: {
                                Text(buttonTitle)
                                    .fontWeight(.semibold)
                                    .font(.title3)
                            }
                            Spacer()
                        }
                        .disabled(!hasChanges)
                        .listRowBackground(
                            hasChanges ? AnyView(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                    Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                    Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                    Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                    Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )) : AnyView(Color(UIColor.systemGray4))
                        )
                        .tint(hasChanges ? .white : .gray)
                    }
                }
                .onAppear {
                    guard let selectedPreset = selectedPreset,
                          let targetBottom = selectedPreset.targetBottom else { return }
                    let computedPercentage = state.computePercentage(target: targetBottom)
                    state.percentage = Double(truncating: computedPercentage as NSNumber)
                    originalPresetName = state.newPresetName
                    originalSettings = ["low": state.low, "duration": state.duration]
                    originalPercentage = state.percentage
                }
                .onDisappear {
                    if !isEditSheetPresented {
                        resetFields()
                    }
                }
                .navigationTitle("Ändra favorit")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Cancel", action: {
                    resetFields()
                    isEditSheetPresented = false
                }))
            }
        }

        private func resetFields() {
            state.newPresetName = ""
            state.low = 0
            state.duration = 0
            state.percentage = 100 // Reset experimental slider if necessary
        }

        private func presetView(for preset: TempTarget) -> some View {
            var low = preset.targetBottom
            if state.units == .mmolL {
                low = low?.asMmolL
            }

            return HStack {
                VStack {
                    HStack {
                        Text(preset.displayName)
                        Spacer()
                    }
                    HStack(spacing: 2) {
                        if let lowValue = low,
                           let formattedLow = formatter.string(from: lowValue as NSNumber)
                        {
                            Text(formattedLow)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }

                        Text(state.units.rawValue)
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Text("i")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        let durationValue = preset.duration
                        let formattedDuration = formatter.string(from: durationValue as NSNumber)
                        Text(formattedDuration ?? "")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Text("min")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    state.enactPreset(id: preset.id)
                }
            }
        }

        private func delete(at offsets: IndexSet) {
            state.presets.remove(atOffsets: offsets)
        }
    }
}
