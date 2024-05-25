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
        @State private var alertString = ""
        @State private var selectedPreset: OverridePresets?
        @State private var isEditSheetPresented: Bool = false
        @State var isSheetPresented: Bool = false
        @State var index: Int = 1
        @State private var showDeleteAlert = false
        @State private var indexToDelete: Int?

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
                nameSection(header: "Ange ett namn")
                settingsSection(header: "Inställningar som sparas")
                Section {
                    Button("Save") {
                        state.savePreset()
                        isSheetPresented = false
                    }
                    .disabled(state.profileName.isEmpty || fetchedProfiles.contains(where: { $0.name == state.profileName }))

                    Button("Cancel") {
                        isSheetPresented = false
                    }
                }
            }
        }

        var editPresetPopover: some View {
            Form {
                nameSection(header: "Behåll eller ändra namn?")
                // settingsSection(header: "Nya inställningar att spara")
                settingsConfig(header: "Ändra inställningar")
                Section {
                    Button("Save") {
                        guard let selectedPreset = selectedPreset else { return }
                        state.updatePreset(selectedPreset)
                        isEditSheetPresented = false
                    }
                    .disabled(state.profileName.isEmpty)

                    Button("Cancel") {
                        isEditSheetPresented = false
                    }
                }
            }
        }

        @ViewBuilder private func nameSection(header: String) -> some View {
            Section {
                TextField("Override preset name", text: $state.profileName)
            } header: {
                Text(header)
            }
        }

        @ViewBuilder private func settingsConfig(header: String) -> some View {
            Section {
                VStack {
                    Spacer()
                    Text("\(state.percentage.formatted(.number)) %")
                        .foregroundColor(
                            state.percentage >= 130 ? .red :
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
                        Text("Aktivera tillsvidare")
                    }
                }
                if !state._indefinite {
                    HStack {
                        Text("Varaktighet")
                        DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: false)
                        Text("minuter")
                    }
                }

                HStack {
                    Toggle(isOn: $state.override_target) {
                        Text("Ändra målvärde")
                    }
                }
                if state.override_target {
                    HStack {
                        Text("Nytt målvärde")
                        DecimalTextField("0", value: $state.target, formatter: glucoseFormatter, cleanInput: false)
                        Text(state.units.rawValue)
                    }
                }
                HStack {
                    Toggle(isOn: $state.advancedSettings) {
                        Text("Mer alternativ")
                    }
                }
                if state.advancedSettings {
                    HStack {
                        Toggle(isOn: $state.smbIsOff) {
                            Text("Inaktivera SMB")
                        }
                    }
                    HStack {
                        Toggle(isOn: $state.smbIsAlwaysOff) {
                            Text("Schemalägg när SMB är av")
                        }.disabled(!state.smbIsOff)
                    }
                    if state.smbIsAlwaysOff {
                        HStack {
                            Text("Första timmen SMB av (24h)")
                            DecimalTextField("0", value: $state.start, formatter: formatter, cleanInput: false)
                            Text("h")
                        }
                        HStack {
                            Text("Sista timmen SMB av (24h)")
                            DecimalTextField("0", value: $state.end, formatter: formatter, cleanInput: false)
                            Text("h")
                        }
                    }
                    HStack {
                        Toggle(isOn: $state.isfAndCr) {
                            Text("Ändra ISF och CR")
                        }
                    }
                    if !state.isfAndCr {
                        HStack {
                            Toggle(isOn: $state.isf) {
                                Text("Ändra ISF")
                            }
                        }
                        HStack {
                            Toggle(isOn: $state.cr) {
                                Text("Ändra CR")
                            }
                        }
                    }
                    HStack {
                        Text("SMB-minuter")
                        DecimalTextField(
                            "0",
                            value: $state.smbMinutes,
                            formatter: formatter,
                            cleanInput: false
                        )
                        Text("minuter")
                    }
                    HStack {
                        Text("UAM-minuter")
                        DecimalTextField(
                            "0",
                            value: $state.uamMinutes,
                            formatter: formatter,
                            cleanInput: false
                        )
                        Text("minuter")
                    }
                }
            } header: {
                Text(header)
            }
        }

        @ViewBuilder private func settingsSection(header: String) -> some View {
            Section(header: Text(header)) {
                let percentString = Text("Override: \(Int(state.percentage))%")
                let targetString = state
                    .target != 0 ? Text("Målvärde: \(state.target.formatted()) \(state.units.rawValue)") : Text("")
                let durationString = state
                    ._indefinite ? Text("Varaktighet: Tillsvidare") :
                    Text("Varaktighet: \(state.duration.formatted()) minuter")
                let isfString = state.isf ? Text("Ändra ISF") : Text("")
                let crString = state.cr ? Text("Ändra CR") : Text("")
                let smbString = state.smbIsOff ? Text("Inaktivera SMB") : Text("")
                let scheduledSMBString = state.smbIsAlwaysOff ? Text("Schemalagda SMB") : Text("")
                let maxMinutesSMBString = state
                    .smbMinutes != 0 ? Text("\(state.smbMinutes.formatted()) SMB Basalminuter") : Text("")
                let maxMinutesUAMString = state
                    .uamMinutes != 0 ? Text("\(state.uamMinutes.formatted()) UAM Basalminuter") : Text("")

                VStack(alignment: .leading, spacing: 2) {
                    percentString
                    if targetString != Text("") { targetString }
                    if durationString != Text("") { durationString }
                    if isfString != Text("") { isfString }
                    if crString != Text("") { crString }
                    if smbString != Text("") { smbString }
                    if scheduledSMBString != Text("") { scheduledSMBString }
                    if maxMinutesSMBString != Text("") { maxMinutesSMBString }
                    if maxMinutesUAMString != Text("") { maxMinutesUAMString }
                }
                .foregroundColor(.secondary)
                .font(.caption)
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
                                Text("Avbryt override")
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
                        ForEach(fetchedProfiles.indices, id: \.self) { index in
                            let preset = fetchedProfiles[index]
                            profilesView(for: preset)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        indexToDelete = index
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Ta bort", systemImage: "trash")
                                    }

                                    Button {
                                        selectedPreset = preset
                                        state.profileName = preset.name ?? ""
                                        isEditSheetPresented = true
                                    } label: {
                                        Label("Redigera", systemImage: "square.and.pencil")
                                    }.tint(.blue)
                                }
                        }
                    }
                    header: { Text("Aktivera sparad override") }
                    footer: { VStack(alignment: .leading) {
                        Text("Svep vänster för att redigera eller radera sparad override.")
                    }
                    }
                }
                settingsConfig(header: "Ställ in Override")

                Section {
                    HStack {
                        Button("Starta ny override") {
                            showAlert.toggle()
                            alertString = "\(state.percentage.formatted(.number)) %, " +
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
                            "Starta ny override",
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
                                Text(alertString)
                            }
                        )
                        Button {
                            isSheetPresented = true
                        }
                        label: { Text("Spara override") }
                            .tint(.blue)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .buttonStyle(BorderlessButtonStyle())
                            .font(.callout)
                            .controlSize(.mini)
                            .disabled(unChanged())
                    }

                    .sheet(isPresented: $isSheetPresented) {
                        presetPopover
                    }
                }
                // header: { Text("Ställ in Override") }
                footer: {
                    Text(
                        "Your profile basal insulin will be adjusted with the override percentage and your profile ISF and CR will be inversly adjusted with the percentage."
                    )
                }
            }
            .onAppear(perform: configureView)
            .onAppear { state.savedSettings() }
            .navigationBarTitle("Overrides")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
            .sheet(isPresented: $isEditSheetPresented) {
                editPresetPopover
                    .padding()
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Radera sparad override"),
                    message: Text("Är du säker på att du vill radera denna override?"),
                    primaryButton: .destructive(Text("Radera")) {
                        if let index = indexToDelete {
                            removeProfile(at: IndexSet(integer: index))
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }

        @ViewBuilder private func profilesView(for preset: OverridePresets) -> some View {
            let target = state.units == .mmolL ? (((preset.target ?? 0) as NSDecimalNumber) as Decimal)
                .asMmolL : (preset.target ?? 0) as Decimal
            let duration = (preset.duration ?? 0) as Decimal
            let name = ((preset.name ?? "") == "") || (preset.name?.isEmpty ?? true) ? "" : preset.name!
            let identifier = ((preset.emoji ?? "") == "") || (preset.emoji?.isEmpty ?? true) || (preset.emoji ?? "") ==
                "\u{0022}\u{0022}" ? "" : preset.emoji!
            let percent = preset.percentage / 100
            let perpetual = preset.indefinite
            let durationString = perpetual ? "" : "\(formatter.string(from: duration as NSNumber)!)"
            let scheduledSMBstring = (preset.smbIsOff && preset.smbIsAlwaysOff) ? "SMB schema •" : ""
            let smbString = (preset.smbIsOff && scheduledSMBstring == "") ? "SMB av •" : ""
            let targetString = target != 0 ? "\(glucoseFormatter.string(from: target as NSNumber)!)" : ""
            let maxMinutesSMB = (preset.smbMinutes as Decimal?) != nil ? (preset.smbMinutes ?? 0) as Decimal : 0
            let maxMinutesUAM = (preset.uamMinutes as Decimal?) != nil ? (preset.uamMinutes ?? 0) as Decimal : 0
            let isfString = preset.isf ? "ISF" : ""
            let crString = preset.cr ? "CR" : ""
            let dash = crString != "" ? "/" : "•"
            let isfAndCRstring = isfString + dash + crString
            if name != "" {
                HStack {
                    VStack {
                        HStack {
                            Text(name)
                            Spacer()
                            Button(action: {
                                selectedPreset = preset
                                state.profileName = preset.name ?? ""
                                isEditSheetPresented = true
                            }) {
                                // Image(systemName: "chevron.left")
                                // .foregroundColor(.secondary)
                            }
                        }
                        HStack(spacing: 2) {
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
                        .padding(.bottom, 2)
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
