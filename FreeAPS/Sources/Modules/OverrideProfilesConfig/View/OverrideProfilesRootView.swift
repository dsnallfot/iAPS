import CoreData
import SwiftUI
import Swinject

extension OverrideProfilesConfig {
    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state = StateModel()
        @State private var isEditing = false
        @State private var showAlert = false
        @State private var showingDetail = false
        @State private var alertSring = ""
        @State var isSheetPresented: Bool = false
        @State var index: Int = 1

        @Environment(\.dismiss) var dismiss
        @Environment(\.managedObjectContext) var moc

        @FetchRequest(
            entity: OverridePresets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "percentage", ascending: true)], predicate: NSPredicate(
                format: "name != %@", "" as String
            )
        ) var fetchedProfiles: FetchedResults<OverridePresets>

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            }
            formatter.roundingMode = .halfUp
            return formatter
        }

        var presetPopover: some View {
            Form {
                Section {
                    TextField("Namn på override", text: $state.profileName)
                } header: { Text("Ange namn på override") }

                Section {
                    Button("Save") {
                        state.savePreset()
                        isSheetPresented = false
                    }
                    .disabled(state.profileName.isEmpty || fetchedProfiles.filter({ $0.name == state.profileName }).isNotEmpty)

                    Button("Cancel") {
                        isSheetPresented = false
                    }
                }
            }
        }

        var body: some View {
            Form {
                if state.isEnabled {
                    Section {
                        Button {
                            state.cancelProfile()
                            dismiss()
                        }
                        label: {
                            HStack {
                                Image(systemName: "x.circle")
                                Text("Avsluta override")
                                    .fontWeight(.semibold)
                                    .font(.title3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color(.loopRed))
                        .tint(.white)
                    }
                }
                if state.presets.isNotEmpty {
                    Section {
                        ForEach(fetchedProfiles) { preset in
                            profilesView(for: preset)
                        }.onDelete(perform: removeProfile)
                    }
                    header: { Text("Aktivera sparad override") }
                }
                Section {
                    VStack {
                        Spacer()
                        Text("\(state.percentage.formatted(.number)) %")
                            .foregroundColor(
                                state
                                    .percentage >= 130 ? .red :
                                    (isEditing ? .orange : .blue)
                            )
                            .font(.largeTitle)
                        Slider(
                            value: $state.percentage,
                            in: 10 ... 200,
                            step: 1,
                            onEditingChanged: { editing in
                                isEditing = editing
                            }
                        ).accentColor(state.percentage >= 130 ? .loopRed : .blue)
                        Spacer()
                        Toggle(isOn: $state._indefinite) {
                            Text("Enable indefinitely")
                        }
                    }
                    if !state._indefinite {
                        HStack {
                            Text("Duration")
                            DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: false)
                            Text("minutes")
                        }
                    }

                    HStack {
                        Toggle(isOn: $state.override_target) {
                            Text("Override Profile Target")
                        }
                    }
                    if state.override_target {
                        HStack {
                            Text("Target Glucose")
                            DecimalTextField("0", value: $state.target, formatter: glucoseFormatter, cleanInput: false)
                            Text(state.units.rawValue)
                        }
                    }
                    HStack {
                        Toggle(isOn: $state.advancedSettings) {
                            Text("More options")
                        }
                    }
                    if state.advancedSettings {
                        HStack {
                            Toggle(isOn: $state.smbIsOff) {
                                Text("Disable SMBs")
                            }
                        }
                        HStack {
                            Toggle(isOn: $state.smbIsAlwaysOff) {
                                Text("Schedule when SMBs are Off")
                            }.disabled(!state.smbIsOff)
                        }
                        if state.smbIsAlwaysOff {
                            HStack {
                                Text("First Hour SMBs are Off (24 hours)")
                                DecimalTextField("0", value: $state.start, formatter: formatter, cleanInput: false)
                                Text("hour")
                            }
                            HStack {
                                Text("Last Hour SMBs are Off (24 hours)")
                                DecimalTextField("0", value: $state.end, formatter: formatter, cleanInput: false)
                                Text("hour")
                            }
                        }
                        HStack {
                            Toggle(isOn: $state.isfAndCr) {
                                Text("Change ISF and CR")
                            }
                        }
                        if !state.isfAndCr {
                            HStack {
                                Toggle(isOn: $state.isf) {
                                    Text("Change ISF")
                                }
                            }
                            HStack {
                                Toggle(isOn: $state.cr) {
                                    Text("Change CR")
                                }
                            }
                        }
                        HStack {
                            Text("SMB Minutes")
                            DecimalTextField(
                                "0",
                                value: $state.smbMinutes,
                                formatter: formatter,
                                cleanInput: false
                            )
                            Text("minutes")
                        }
                        HStack {
                            Text("UAM SMB Minutes")
                            DecimalTextField(
                                "0",
                                value: $state.uamMinutes,
                                formatter: formatter,
                                cleanInput: false
                            )
                            Text("minutes")
                        }
                    }

                    HStack {
                        Button("Aktivera ny override") {
                            showAlert.toggle()
                            alertSring = "\(state.percentage.formatted(.number)) %, " +
                                (
                                    state.duration > 0 || !state
                                        ._indefinite ?
                                        (
                                            state
                                                .duration
                                                .formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) +
                                                " min."
                                        ) :
                                        NSLocalizedString(" infinite duration.", comment: "")
                                ) +
                                (
                                    (state.target == 0 || !state.override_target) ? "" :
                                        (" Target: " + state.target.formatted() + " " + state.units.rawValue + ".")
                                )
                                +
                                (
                                    state
                                        .smbIsOff ?
                                        NSLocalizedString(
                                            " SMBs are disabled either by schedule or during the entire duration.",
                                            comment: ""
                                        ) : ""
                                )
                                +
                                "\n\n"
                                +
                                NSLocalizedString(
                                    "Starting this override will change your Profiles and/or your Target Glucose used for looping during the entire selected duration. Tapping ”Start Profile” will start your new profile or edit your current active profile.",
                                    comment: ""
                                )
                        }
                        .disabled(unChanged())

                        .buttonStyle(BorderlessButtonStyle())
                        .font(.callout)
                        .controlSize(.mini)
                        .alert(
                            "Starta override",
                            isPresented: $showAlert,
                            actions: {
                                Button("Cancel", role: .cancel) { state.isEnabled = false }
                                Button("Starta override", role: .destructive) {
                                    if state._indefinite { state.duration = 0 }
                                    state.isEnabled.toggle()
                                    state.saveSettings()
                                    dismiss()
                                }
                            },
                            message: {
                                Text(alertSring)
                            }
                        )
                        Button {
                            isSheetPresented = true
                        }
                        label: { Text("Spara ny override") }
                            .tint(.blue)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .buttonStyle(BorderlessButtonStyle())
                            .controlSize(.mini)
                            .disabled(unChanged())
                    }

                    .sheet(isPresented: $isSheetPresented) {
                        presetPopover
                    }
                }

                header: { Text("Ställ in ny override") }
                footer: {
                    Text(
                        "Your profile basal insulin will be adjusted with the override percentage and your profile ISF and CR will be inversly adjusted with the percentage."
                    )
                }
            }
            .onAppear(perform: configureView)
            .onAppear { state.savedSettings() }
            .navigationBarTitle("Override")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
        }

        @ViewBuilder private func profilesView(for preset: OverridePresets) -> some View {
            let target = state.units == .mmolL ? (((preset.target ?? 0) as NSDecimalNumber) as Decimal)
                .asMmolL : (preset.target ?? 0) as Decimal
            let duration = (preset.duration ?? 0) as Decimal
            let name = ((preset.name ?? "") == "") || (preset.name?.isEmpty ?? true) ? "" : preset.name!
            let identifier = ((preset.emoji ?? "") == "") || (preset.emoji?.isEmpty ?? true) ||
                (preset.emoji ?? "") == "\u{0022}\u{0022}" ?
                "" : preset.emoji!
            let percent = preset.percentage / 100
            let perpetual = preset.indefinite
            let durationString = perpetual ? "" : "\(formatter.string(from: duration as NSNumber)!)"
            let scheduledSMBstring = (preset.smbIsOff && preset.smbIsAlwaysOff) ? "SMB schema •" : ""
            let smbString = (preset.smbIsOff && scheduledSMBstring == "") ? "SMB av •" : ""
            let targetString = target != 0 ? "\(glucoseFormatter.string(from: target as NSNumber)!)" : ""
            let maxMinutesSMB = (preset.smbMinutes as Decimal?) != nil ? (preset.smbMinutes ?? 0) as Decimal : 0
            let maxMinutesUAM = (preset.uamMinutes as Decimal?) != nil ? (preset.uamMinutes ?? 0) as Decimal : 0

            let isfString = preset.isf ? "ISF" : ""
            let crString = preset.cr ? "CR •" : ""
            let dash = crString != "" ? "/" : "•"
            let isfAndCRstring = isfString + dash + crString

            if name != "" {
                HStack {
                    VStack {
                        HStack {
                            Text(name)
                            Spacer()
                        }
                        HStack(spacing: 3) {
                            Text(percent.formatted(.percent.grouping(.never).rounded().precision(.fractionLength(0))))
                            if targetString != "" {
                                Text(targetString)
                                Text(targetString != "" ? "mmol" : "")
                            }
                            if durationString != "" { Text(durationString + (perpetual ? "" : "m")) }
                            if preset.advancedSettings {
                                Text(isfAndCRstring)
                            }
                            if smbString != "" { Text(smbString).foregroundColor(.secondary).font(.caption) }
                            if scheduledSMBstring != "" { Text(scheduledSMBstring) }
                            if preset.advancedSettings {
                                Text(maxMinutesSMB == 0 ? "" : maxMinutesSMB.formatted() + " SMB")
                                Text(maxMinutesUAM == 0 ? "" : maxMinutesUAM.formatted() + " UAM")
                            }
                            Spacer()
                        }
                        .padding(.top, 2)
                        .foregroundColor(.secondary)
                        .font(.caption2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.selectProfile(id_: preset.id ?? "")
                        state.hideModal()
                    }
                }
            }
        }

        private func unChanged() -> Bool {
            let isChanged = (state.percentage == 100 && !state.override_target && !state.smbIsOff && !state.advancedSettings) ||
                (!state._indefinite && state.duration == 0) || (state.override_target && state.target == 0) ||
                (
                    state.percentage == 100 && !state.override_target && !state.smbIsOff && state.isf && state.cr && state
                        .smbMinutes == state.defaultSmbMinutes && state.uamMinutes == state.defaultUamMinutes
                )

            return isChanged
        }

        private func removeProfile(at offsets: IndexSet) {
            for index in offsets {
                let language = fetchedProfiles[index]
                moc.delete(language)
            }
            do {
                try moc.save()
            } catch {
                // To do: add error
            }
        }
    }
}
