import CoreData
import SpriteKit
import SwiftDate
import SwiftUI
import Swinject

extension Home {
    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state = StateModel()
        @State var isStatusPopupPresented = false
        @State var showCancelAlert = false

        struct Buttons: Identifiable {
            let label: String
            let number: String
            var active: Bool
            let hours: Int16
            var id: String { label }
        }

        @State var timeButtons: [Buttons] = [
            Buttons(label: "2 hours", number: "2", active: false, hours: 2),
            Buttons(label: "4 hours", number: "4", active: false, hours: 4),
            Buttons(label: "6 hours", number: "6", active: false, hours: 6),
            Buttons(label: "12 hours", number: "12", active: false, hours: 12),
            Buttons(label: "24 hours", number: "24", active: false, hours: 24)
        ]

        let buttonFont = Font.custom("TimeButtonFont", size: 12)

        @Environment(\.managedObjectContext) var moc
        @Environment(\.colorScheme) var colorScheme

        @FetchRequest(
            entity: Override.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var fetchedPercent: FetchedResults<Override>

        @FetchRequest(
            entity: OverridePresets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], predicate: NSPredicate(
                format: "name != %@", "" as String
            )
        ) var fetchedProfiles: FetchedResults<OverridePresets>

        @FetchRequest(
            entity: TempTargets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var sliderTTpresets: FetchedResults<TempTargets>

        @FetchRequest(
            entity: TempTargetsSlider.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var enactedSliderTT: FetchedResults<TempTargetsSlider>

        @FetchRequest(
            entity: UXSettings.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var fetchedSettings: FetchedResults<UXSettings>

        private var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var fetchedTargetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            } else { formatter.maximumFractionDigits = 0 }
            return formatter
        }

        private var targetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var tirFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            return dateFormatter
        }

        private var spriteScene: SKScene {
            let scene = SnowScene()
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            return scene
        }

        @ViewBuilder func header(_ geo: GeometryProxy) -> some View {
            VStack(alignment: .center) {
                glucoseView
                    .padding(.bottom, 22)
                    .padding(.top, 8)
                HStack(alignment: .bottom) {
                    // Spacer()
                    cobIobView
                    // Spacer()
                    pumpView
                    // Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10 + geo.safeAreaInsets.top)
            .padding(.bottom, 0)
            .padding(.leading, 8)
            .padding(.trailing, 8)
            .background(Color.blue.opacity(0.12))
        }

        var cobIobView: some View {
            HStack {
                Text("IOB")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                Text(
                    (numberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0") +
                        NSLocalizedString(" U", comment: "Insulin unit")
                )
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                .padding(.trailing, 16)
                Text("COB")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                Text(
                    (numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0") +
                        NSLocalizedString(" g", comment: "gram of carbs")
                )
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                .padding(.trailing, 16)
            }
            .onTapGesture {
                state.showModal(for: .dataTable)
            } }

        var glucoseView: some View {
            CurrentGlucoseView(
                recentGlucose: $state.recentGlucose,
                timerDate: $state.timerDate,
                delta: $state.glucoseDelta,
                units: $state.units,
                alarm: $state.alarm,
                lowGlucose: $state.lowGlucose,
                highGlucose: $state.highGlucose
            )
            .onTapGesture {
                if state.alarm == nil {
                    state.showModal(for: .snooze)
                } else {
                    state.showModal(for: .snooze)
                }
            }
            .onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                if state.alarm == nil {
                    state.openCGM()
                } else {
                    state.openCGM()
                }
            }
        }

        var pumpView: some View {
            PumpView(
                reservoir: $state.reservoir,
                battery: $state.battery,
                name: $state.pumpName,
                expiresAtDate: $state.pumpExpiresAtDate,
                timerDate: $state.timerDate,
                timeZone: $state.timeZone
            )
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
        }

        var loopView: some View {
            LoopView(
                suggestion: $state.suggestion,
                enactedSuggestion: $state.enactedSuggestion,
                closedLoop: $state.closedLoop,
                timerDate: $state.timerDate,
                isLooping: $state.isLooping,
                lastLoopDate: $state.lastLoopDate,
                manualTempBasal: $state.manualTempBasal,
                timeZone: $state.timeZone
            ).onTapGesture {
                isStatusPopupPresented.toggle()
            }.onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                state.runLoop()
            }
        }

        var tempBasalString: String? {
            guard let tempRate = state.tempRate else {
                return nil
            }
            let rateString = numberFormatter.string(from: tempRate as NSNumber) ?? "0"
            var manualBasalString = ""

            if state.apsManager.isManualTempBasal {
                manualBasalString = NSLocalizedString(
                    " - Manual Basal ⚠️",
                    comment: "Manual Temp basal"
                )
            }
            return rateString + NSLocalizedString(" U/hr", comment: "Unit per hour with space") + manualBasalString
        }

        var tempTargetString: String? {
            guard let tempTarget = state.tempTarget else {
                return nil
            }
            let target = tempTarget.targetBottom ?? 0
            let unitString = targetFormatter.string(from: (tempTarget.targetBottom?.asMmolL ?? 0) as NSNumber) ?? ""
            let rawString = (tirFormatter.string(from: (tempTarget.targetBottom ?? 0) as NSNumber) ?? "") + " " + state.units
                .rawValue

            var string = ""
            if sliderTTpresets.first?.active ?? false {
                let hbt = sliderTTpresets.first?.hbt ?? 0
                string = ", " + (tirFormatter.string(from: state.infoPanelTTPercentage(hbt, target) as NSNumber) ?? "") + " %"
            }

            let percentString = state
                .units == .mmolL ? (unitString + " mmol/L" + string) : (rawString + (string == "0" ? "" : string))
            return tempTarget.displayName + " " + percentString
        }

        var overrideString: String? {
            guard fetchedPercent.first?.enabled ?? false else {
                return nil
            }
            var percentString = "\((fetchedPercent.first?.percentage ?? 100).formatted(.number)) %"
            var target = (fetchedPercent.first?.target ?? 100) as Decimal
            let indefinite = (fetchedPercent.first?.indefinite ?? false)
            let unit = state.units.rawValue
            if state.units == .mmolL {
                target = target.asMmolL
            }
            var targetString = (fetchedTargetFormatter.string(from: target as NSNumber) ?? "") + " " + unit
            if tempTargetString != nil || target == 0 { targetString = "" }
            percentString = percentString == "100 %" ? "" : percentString

            let duration = (fetchedPercent.first?.duration ?? 0) as Decimal
            let addedMinutes = Int(duration)
            let date = fetchedPercent.first?.date ?? Date()
            var newDuration: Decimal = 0

            if date.addingTimeInterval(addedMinutes.minutes.timeInterval) > Date() {
                newDuration = Decimal(Date().distance(to: date.addingTimeInterval(addedMinutes.minutes.timeInterval)).minutes)
            }

            var durationString = indefinite ?
                "" : newDuration >= 1 ?
                (newDuration.formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) + " min") :
                (
                    newDuration > 0 ? (
                        (newDuration * 60).formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) + " s"
                    ) :
                        ""
                )

            let smbToggleString = (fetchedPercent.first?.smbIsOff ?? false) ? " \u{20e0}" : ""
            var comma1 = ", "
            var comma2 = comma1
            var comma3 = comma1
            if targetString == "" || percentString == "" { comma1 = "" }
            if durationString == "" { comma2 = "" }
            if smbToggleString == "" { comma3 = "" }

            if percentString == "", targetString == "" {
                comma1 = ""
                comma2 = ""
            }
            if percentString == "", targetString == "", smbToggleString == "" {
                durationString = ""
                comma1 = ""
                comma2 = ""
                comma3 = ""
            }
            if durationString == "" {
                comma2 = ""
            }
            if smbToggleString == "" {
                comma3 = ""
            }

            if durationString == "", !indefinite {
                return nil
            }
            return percentString + comma1 + targetString + comma2 + durationString + comma3 + smbToggleString
        }

        var infoPanel: some View {
            HStack(alignment: .center) {
                if state.pumpSuspended {
                    Text("Pump suspended")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.loopGray)
                        .padding(.leading, 8)
                } else if let tempBasalString = tempBasalString {
                    Text(tempBasalString)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.insulin)
                        .padding(.leading, 8)
                }

                Button(action: {
                    state.showModal(for: .addTempTarget)
                }) {
                    if let tempTargetString = tempTargetString {
                        Text(tempTargetString)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                Button(action: {
                    state.showModal(for: .overrideProfilesConfig)
                }) {
                    if let overrideString = overrideString {
                        Text(selectedProfile().name)
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        Text(overrideString)
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                            .padding(.trailing, 8)
                    }
                }

                if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                    (Text(Image(systemName: "exclamationmark.triangle")) + Text(" Max IOB: 0"))
                        .font(.callout)
                        .foregroundColor(.orange)
                        .padding(.trailing, 8)
                        .onTapGesture {
                            state.showModal(for: .preferencesEditor)
                        }
                }

                if let progress = state.bolusProgress {
                    HStack {
                        Text("Bolusing")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.insulin)
                        ProgressView(value: Double(progress))
                            .progressViewStyle(BolusProgressViewStyle())
                            .padding(.trailing, 8)
                    }
                    .onTapGesture {
                        state.cancelBolus()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 40)
            .background(Color.blue.opacity(0.12))
        }

        var timeInterval: some View {
            HStack(alignment: .center) {
                ForEach(timeButtons) { button in
                    Text(button.active ? NSLocalizedString(button.label, comment: "") : button.number).onTapGesture {
                        state.hours = button.hours
                        highlightButtons()
                    }
                    .foregroundStyle(button.active ? .primary : .secondary)
                    .frame(maxHeight: 20)
                    .padding(.horizontal)
                    .padding(.vertical, 3)
                    .background(button.active ? Color.blue.opacity(0.12) : .clear, in: .capsule(style: .circular))
                }
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(.purple.opacity(0.5))
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.leading)
                    .onTapGesture {
                        state.showModal(for: .statistics)
                    }
            }
            .font(buttonFont)
            .padding(.top, 0)
            .padding(.bottom, 8)
        }

        var legendPanel: some View {
            ZStack {
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.loopGreen).frame(width: 8, height: 8)
                        Text("BG").font(.system(size: 12, weight: .semibold)).foregroundColor(.loopGreen)
                    }
                    .frame(width: 45)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.loopYellow).frame(width: 8, height: 8)
                        Text("COB").font(.system(size: 12, weight: .semibold)).foregroundColor(.loopYellow)
                    }
                    .frame(width: 45)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.uam).frame(width: 8, height: 8)
                        Text("UAM")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.uam)
                    }
                    .frame(width: 45)

                    Spacer()

                    loopView
                        .offset(x: 0, y: 8)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.insulin).frame(width: 8, height: 8)
                        Text("IOB").font(.system(size: 12, weight: .semibold)).foregroundColor(.insulin)
                    }
                    .frame(width: 45)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.zt).frame(width: 8, height: 8)
                        Text("ZT").font(.system(size: 12, weight: .semibold)).foregroundColor(.zt)
                    }
                    .frame(width: 45)

                    Spacer()
                    HStack(spacing: 4) {
                        if let eventualBG = state.eventualBG {
                            Text(
                                "⇢ " + numberFormatter.string(
                                    from: (state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                                )!
                            )
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 45)
                    .onTapGesture {
                        isStatusPopupPresented.toggle()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding([.bottom], 14)
                .padding(.leading, 6)
                .padding(.trailing, 8)
                .onTapGesture {
                    isStatusPopupPresented.toggle()
                }
            }
        }

        var mainChart: some View {
            ZStack {
                if state.animatedBackground {
                    SpriteView(scene: spriteScene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }

                MainChartView(
                    glucose: $state.glucose,
                    isManual: $state.isManual,
                    suggestion: $state.suggestion,
                    tempBasals: $state.tempBasals,
                    boluses: $state.boluses,
                    suspensions: $state.suspensions,
                    announcement: $state.announcement,
                    hours: .constant(state.filteredHours),
                    maxBasal: $state.maxBasal,
                    autotunedBasalProfile: $state.autotunedBasalProfile,
                    basalProfile: $state.basalProfile,
                    tempTargets: $state.tempTargets,
                    carbs: $state.carbs,
                    timerDate: $state.timerDate,
                    units: $state.units,
                    smooth: $state.smooth,
                    highGlucose: $state.highGlucose,
                    lowGlucose: $state.lowGlucose,
                    screenHours: $state.hours,
                    displayXgridLines: $state.displayXgridLines,
                    displayYgridLines: $state.displayYgridLines,
                    thresholdLines: $state.thresholdLines
                )
            }
            .padding(.bottom)
            .modal(for: .dataTable, from: self)
        }

        private func selectedProfile() -> (name: String, isOn: Bool) {
            var profileString = ""
            var display: Bool = false

            let duration = (fetchedPercent.first?.duration ?? 0) as Decimal
            let indefinite = fetchedPercent.first?.indefinite ?? false
            let addedMinutes = Int(duration)
            let date = fetchedPercent.first?.date ?? Date()
            if date.addingTimeInterval(addedMinutes.minutes.timeInterval) > Date() || indefinite {
                display.toggle()
            }

            if fetchedPercent.first?.enabled ?? false, !(fetchedPercent.first?.isPreset ?? false), display {
                profileString = NSLocalizedString("Custom Profile", comment: "Custom but unsaved Profile")
            } else if !(fetchedPercent.first?.enabled ?? false) || !display {
                profileString = NSLocalizedString("Normal Profile", comment: "Your normal Profile. Use a short string")
            } else {
                let id_ = fetchedPercent.first?.id ?? ""
                let profile = fetchedProfiles.filter({ $0.id == id_ }).first
                if profile != nil {
                    profileString = profile?.name?.description ?? ""
                }
            }
            return (name: profileString, isOn: display)
        }

        func highlightButtons() {
            for i in 0 ..< timeButtons.count {
                timeButtons[i].active = timeButtons[i].hours == state.hours
            }
        }

        @ViewBuilder private func bottomPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                Rectangle().fill(Color.blue.opacity(0.12)).frame(height: 70 + geo.safeAreaInsets.bottom)

                HStack {
                    Button { state.showModal(for: .addCarbs(editMode: false, override: false)) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image("carbs")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 27, height: 27)
                                .foregroundColor(.loopYellow)
                                .padding(.top, 27)
                                .padding(.bottom, 8)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                            if let carbsReq = state.carbsRequired {
                                Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Capsule().fill(Color.purple))
                            }
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    Button { state.showModal(for: .addTempTarget) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image("target")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.loopGreen)
                                .padding(.top, 25)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 6)
                            if state.tempTarget != nil {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Capsule().fill(Color.purple))
                            }
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    Button {
                        state.showModal(for: .bolus(
                            waitForSuggestion: true,
                            fetch: false
                        ))
                        // Daniel: Add determinebasalsync to force update before entering bolusview
                        state.apsManager.determineBasalSync()
                    } label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image("bolus")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 27, height: 27)
                                .foregroundColor(.insulin)
                                .padding(.top, 27)
                                .padding(.bottom, 8)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)

                            if let insulinRequested = state.suggestion?.insulinReq, insulinRequested > 0 {
                                Image(systemName: "plus.circle")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Capsule().fill(Color.purple))
                            }
                        }
                    }
                    Spacer()
                    if state.allowManualTemp {
                        Button { state.showModal(for: .manualTempBasal) }
                        label: {
                            Image("bolus1")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 27, height: 27)
                                .padding(.top, 27)
                                .padding(.bottom, 8)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                        }.foregroundColor(.insulin)
                        Spacer()
                    }
                    Button { state.showModal(for: .overrideProfilesConfig) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image(systemName: "person.fill")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 27, height: 27)
                                .foregroundColor(.cyan)
                                .padding(.top, 27)
                                .padding(.bottom, 8)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                            if selectedProfile().isOn {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Capsule().fill(Color.purple))
                            }
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    Button { state.showModal(for: .settings) }
                    label: {
                        Image("settings1")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 27, height: 27)
                            .padding(.top, 27)
                            .padding(.bottom, 8)
                            .padding(.leading, 9)
                            .padding(.trailing, 9)
                    }.foregroundColor(.gray)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, geo.safeAreaInsets.bottom)
            }
        }

        var body: some View {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    header(geo)
                    infoPanel
                    mainChart
                    timeInterval
                    legendPanel
                    bottomPanel(geo)
                }
                .edgesIgnoringSafeArea(.vertical)
            }
            .onChange(of: state.hours) { _ in
                highlightButtons()
            }
            .onAppear {
                configureView {
                    highlightButtons()
                }
            }
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .popup(isPresented: isStatusPopupPresented, alignment: .top, direction: .top) {
                popup
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(UIColor.systemGray4))
                    )
                    .onTapGesture {
                        isStatusPopupPresented = false
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height < 0 {
                                    isStatusPopupPresented = false
                                }
                            }
                    )
            }
            .onDisappear {
                state.saveSettings()
            }
        }

        private var popup: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusTitle).font(.headline).foregroundColor(.primary)
                    .padding(.bottom, 4)
                if let suggestion = state.suggestion {
                    TagCloudView(tags: suggestion.reasonParts).animation(.none, value: false)

                    Text(suggestion.reasonConclusion.capitalizingFirstLetter()).font(.caption).foregroundColor(.primary)

                } else {
                    Text("No suggestion found").font(.body).foregroundColor(.primary)
                }

                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    Text(NSLocalizedString("Error at", comment: "") + " " + dateFormatter.string(from: date))
                        .foregroundColor(.primary)
                        .font(.headline)
                        .padding(.bottom, 4)
                        .padding(.top, 8)
                    Text(errorMessage).font(.caption).foregroundColor(.loopRed)
                }
            }
        }
    }
}
