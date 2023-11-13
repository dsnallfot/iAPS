import CoreData
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

        @FetchRequest(
            entity: TempTargetsSlider.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var isEnabledArray: FetchedResults<TempTargetsSlider>

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
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
                                Text("Avbryt tillfälligt mål")
                                    .fontWeight(.semibold)
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
                                .swipeActions {
                                    Button(role: .destructive, action: {
                                        removeAlert = Alert(
                                            title: Text("Are you sure?"),
                                            message: Text("Delete preset \"\(preset.displayName)\""),
                                            primaryButton: .destructive(Text("Delete"), action: {
                                                state.removePreset(id: preset.id)
                                                isRemoveAlertPresented = false // Dismiss the alert after deletion
                                            }),
                                            secondaryButton: .cancel()
                                        )
                                        isRemoveAlertPresented = true
                                    }) {
                                        Text("Delete")
                                    }
                                }
                                .alert(isPresented: $isRemoveAlertPresented) {
                                    removeAlert!
                                }
                        }
                        .onDelete(perform: delete)
                    }
                }
                HStack {
                    Text("Override %")
                    Toggle(isOn: $state.viewPercantage) {}.controlSize(.mini)
                }

                if state.viewPercantage {
                    Section(header: Text("Ställ in en procentuell override")) {
                        VStack {
                            Text("\(state.percentage.formatted(.number)) % Insulin")
                                .foregroundColor(isEditing ? .orange : .blue)
                                .font(.largeTitle)
                                .padding(.vertical)
                            Spacer()
                            Slider(
                                value: $state.percentage,
                                in: 15 ...
                                    min(Double(state.maxValue * 100), 200),
                                step: 1,
                                onEditingChanged: { editing in
                                    isEditing = editing
                                }
                            )

                            // Only display target slider when not 100 %
                            if state.percentage != 100 {
                                Divider()
                                Text(
                                    (
                                        state
                                            .units == .mmolL ?
                                            "\(state.computeTarget().asMmolL.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))) mmol/L" :
                                            "\(state.computeTarget().formatted(.number.grouping(.never).rounded().precision(.fractionLength(0)))) mg/dl"
                                    )
                                        + NSLocalizedString("  Målvärde", comment: "")
                                )
                                .foregroundColor(.green)

                                Slider(
                                    value: $state.hbt,
                                    in: 101 ... 295,
                                    step: 1
                                ).accentColor(.green)
                            }
                        }
                    }
                } else {
                    Section(header: Text("Ställ in ett tillfälligt mål")) {
                        HStack {
                            Text("Target")
                            Spacer()
                            DecimalTextField("0", value: $state.low, formatter: formatter, cleanInput: true)
                            Text(state.units.rawValue)
                        }
                        HStack {
                            Text("Duration")
                            Spacer()
                            DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: true)
                            Text("minutes")
                        }
                        DatePicker("Date", selection: $state.date)
                        HStack {
                            Button { state.enact() }
                            label: { Text("Aktivera tillfälligt mål") }
                                .disabled(state.duration == 0)
                                .controlSize(.mini)
                                .buttonStyle(BorderlessButtonStyle())
                            Spacer()
                            Button { isPromptPresented = true }
                            label: { Text("Spara favorit") }
                                .disabled(state.duration == 0)
                                .controlSize(.mini)
                                .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                if state.viewPercantage {
                    Section {
                        HStack {
                            Text("Duration")
                            Spacer()
                            DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: true)
                            Text("minutes")
                        }
                        DatePicker("Date", selection: $state.date)
                        HStack {
                            Button { state.enact() }
                            label: { Text("Aktivera override") }
                                .disabled(state.duration == 0)
                                .controlSize(.mini)
                                .buttonStyle(BorderlessButtonStyle())
                            Spacer()
                            Button { isPromptPresented = true }
                            label: { Text("Spara favorit") }
                                .disabled(state.duration == 0)
                                .controlSize(.mini)
                                .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }
            .popover(isPresented: $isPromptPresented) {
                Form {
                    Section(header: Text("Ange namn på favorit")) {
                        TextField("Name", text: $state.newPresetName)
                        Button {
                            state.save()
                            isPromptPresented = false
                        }
                        label: { Text("Save") }
                        Button { isPromptPresented = false }
                        label: { Text("Cancel") }
                    }
                }
            }
            .onAppear {
                configureView()
                state.hbt = isEnabledArray.first?.hbt ?? 160
            }
            .navigationTitle("Tillfälliga mål")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
        }

        private func presetView(for preset: TempTarget) -> some View {
            var low = preset.targetBottom
            var high = preset.targetTop
            if state.units == .mmolL {
                low = low?.asMmolL
                high = high?.asMmolL
            }
            return HStack {
                VStack {
                    HStack {
                        Text(preset.displayName)
                        Spacer()
                    }
                    HStack(spacing: 2) {
                        Text(
                            "\(formatter.string(from: (low ?? 0) as NSNumber)!)"
                        )
                        .foregroundColor(.secondary)
                        .font(.caption)

                        Text(state.units.rawValue)
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("for")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(formatter.string(from: preset.duration as NSNumber)!)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("min")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Spacer()
                    }.padding(.top, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    state.enactPreset(id: preset.id)
                }

                /* Image(systemName: "xmark.circle").foregroundColor(.secondary)
                 .contentShape(Rectangle())
                 .padding(.vertical)
                 .onTapGesture {
                 removeAlert = Alert(
                 title: Text("Are you sure?"),
                 message: Text("Delete preset \"\(preset.displayName)\""),
                 primaryButton: .destructive(Text("Delete"), action: { state.removePreset(id: preset.id) }),
                 secondaryButton: .cancel()
                 )
                 isRemoveAlertPresented = true
                 }
                 .alert(isPresented: $isRemoveAlertPresented) {
                 removeAlert!
                 } */
            }
        }

        private func delete(at offsets: IndexSet) {
            state.presets.remove(atOffsets: offsets)
        }
    }
}
