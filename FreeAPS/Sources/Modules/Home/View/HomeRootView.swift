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
            formatter.maximumFractionDigits = 2
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
                    .padding(.bottom, 30)
                    .padding(.top, 12)

                HStack(alignment: .center) {
                    cobIobView
                        .frame(width: 140, alignment: .leading)
                    Spacer()
                    HStack {
                        if state.pumpSuspended {
                            Text("Basal")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                            Text("--")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                                .offset(x: -2, y: 0)
                        } else if let tempBasalString = tempBasalString {
                            Text("Basal")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                            Text(tempBasalString)
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                                .offset(x: -2, y: 0)
                        }
                    }
                    .frame(width: 80)
                    .onTapGesture {
                        state.showModal(for: .dataTable)
                    }
                    Spacer()

                    pumpView
                        .frame(width: 120, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10 + geo.safeAreaInsets.top)
            .padding(.horizontal, 10)
            .background(Color.clear)
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
            return rateString + NSLocalizedString("E/h", comment: "Unit per hour with space") + manualBasalString
        }

        var cobIobView: some View {
            HStack {
                HStack {
                    Text("IOB")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Text(
                        (numberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0,00") +
                            NSLocalizedString("E", comment: "Insulin unit")
                    )
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                    .offset(x: -2, y: 0)
                }
                .frame(width: 70, alignment: .leading)
                .onTapGesture {
                    state.showModal(for: .dataTable)
                }

                Spacer()
                HStack {
                    Text("COB")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Text(
                        (numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0") +
                            NSLocalizedString("g", comment: "gram of carbs")
                    )
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                    .offset(x: -2, y: 0)
                }
                .frame(width: 70, alignment: .leading)
                .onTapGesture {
                    state.showModal(for: .dataTable)
                }
            }
        }

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
                string = " " + (tirFormatter.string(from: state.infoPanelTTPercentage(hbt, target) as NSNumber) ?? "") + " %"
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
            var comma1 = " "
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
                Spacer()
                Button(action: {
                    if state.pumpDisplayState != nil {
                        state.setupPump = true
                    }
                }) {
                    if state.pumpSuspended {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .offset(x: 0, y: 0)

                            Text("Pump suspended")
                                .offset(x: -4, y: 0)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxHeight: 20)
                        .padding(.vertical, 3)
                        .padding(.leading, 9)
                        .padding(.trailing, 5)
                        .background(colorScheme == .dark ? Color.basal.opacity(0.3) : Color.white)
                        .cornerRadius(13)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.secondary.opacity(1), lineWidth: 1)
                )
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33),
                    radius: colorScheme == .dark ? 5 : 3
                )
                if state.pumpSuspended {
                    Spacer()
                }

                Button(action: {
                    state.showModal(for: .addCarbs(editMode: false, override: false)) }) {
                    if let carbsReq = state.carbsRequired {
                        HStack {
                            Text(numberFormatter.string(from: carbsReq as NSNumber)!)

                            Text("g kh krävs!")
                                .offset(x: -5, y: 0)
                        }
                        .font(.caption)
                        .foregroundColor(.loopYellow)
                        .frame(maxHeight: 20)
                        .padding(.vertical, 3)
                        .padding(.leading, 9)
                        .padding(.trailing, 4)
                        .background(colorScheme == .dark ? Color.basal.opacity(0.3) : Color.white)
                        .cornerRadius(13)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.loopYellow.opacity(1), lineWidth: 1)
                )
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33),
                    radius: colorScheme == .dark ? 5 : 3
                )
                if state.carbsRequired != nil {
                    Spacer()
                }
                Button(action: {
                    state.showModal(for: .addTempTarget)
                }) {
                    if let tempTargetString = tempTargetString {
                        Text(tempTargetString)
                            .font(.caption)
                            .foregroundColor(.loopGreen)
                            .frame(maxHeight: 20)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 9)
                            .background(colorScheme == .dark ? Color.basal.opacity(0.3) : Color.white)
                            .cornerRadius(13)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.loopGreen.opacity(1), lineWidth: 1)
                )
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33),
                    radius: colorScheme == .dark ? 5 : 3
                )
                if tempTargetString != nil {
                    Spacer()
                }

                Button(action: {
                    state.showModal(for: .bolus(
                        waitForSuggestion: true,
                        fetch: false
                    ))
                    // Daniel: Add determinebasalsync to force update before entering bolusview
                    state.apsManager.determineBasalSync() }) {
                    if let insulinRequested = state.suggestion?.insulinReq, insulinRequested > 0.3 {
                        HStack {
                            Text("Insulinbehov")
                                .offset(x: 5, y: 0)
                            Text(numberFormatter.string(from: insulinRequested as NSNumber)!)

                            Text("E")
                                .offset(x: -5, y: 0)
                        }
                        .font(.caption)
                        .foregroundColor(.insulin)
                        .frame(maxHeight: 20)
                        .padding(.vertical, 3)
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                        .background(colorScheme == .dark ? Color.basal.opacity(0.3) : Color.white)
                        .cornerRadius(13)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.insulin.opacity(1), lineWidth: 1)
                )
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33),
                    radius: colorScheme == .dark ? 5 : 3
                )
                if let insulinRequested = state.suggestion?.insulinReq, insulinRequested > 0.3 {
                    Spacer()
                }

                Button(action: {
                    state.showModal(for: .overrideProfilesConfig)
                })
                    {
                        if let overrideString = overrideString {
                            HStack {
                                Text(selectedProfile().name)
                                Text(overrideString)
                            }
                            .font(.caption)
                            .foregroundColor(.cyan)
                            .frame(maxHeight: 20)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 9)
                            .background(colorScheme == .dark ? Color.basal.opacity(0.3) : Color.white)
                            .cornerRadius(13)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(Color.cyan.opacity(1.0), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33),
                        radius: colorScheme == .dark ? 5 : 3
                    )
                if overrideString != nil {
                    Spacer()
                }
                Button(action: {
                    state.showModal(for: .preferencesEditor)
                })
                    {
                        if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .offset(x: 0, y: 0)

                                Text("Max IOB: 0")
                                    .offset(x: -4, y: 0)
                            }
                            .font(.caption)
                            .foregroundColor(.loopRed)
                            .frame(maxHeight: 20)
                            .padding(.vertical, 3)
                            .padding(.leading, 9)
                            .padding(.trailing, 4)
                            .background(colorScheme == .dark ? Color.basal.opacity(0.3) : Color.white)
                            .cornerRadius(13)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(Color.loopRed.opacity(1.0), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33),
                        radius: colorScheme == .dark ? 5 : 3
                    )
                if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                    Spacer()
                }
                if let progress = state.bolusProgress {
                    HStack {
                        Text("Bolusing")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.insulin)
                        ProgressView(value: Double(progress))
                            .progressViewStyle(BolusProgressViewStyle())
                    }
                    .onTapGesture {
                        state.cancelBolus()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 40)
            .background(Color.clear)
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .padding(.bottom, 5)
        }

        var timeInterval: some View {
            HStack(alignment: .center) {
                ForEach(timeButtons) { button in
                    Text(button.active ? NSLocalizedString(button.label, comment: "") : button.number).onTapGesture {
                        state.hours = button.hours
                        highlightButtons()
                    }
                    .foregroundStyle(button.active ? .secondary : .secondary)
                    .frame(maxHeight: 20)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        button.active ?
                            (
                                colorScheme == .dark ? Color.basal.opacity(0.3) :
                                    Color.white
                            ) :
                            Color
                            .clear
                    )
                    .cornerRadius(13)
                }
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple.opacity(0.7))
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.leading)
                    .onTapGesture {
                        state.showModal(for: .statistics)
                    }
            }
            .font(buttonFont)
            .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33), radius: colorScheme == .dark ? 5 : 3)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }

        var legendPanel: some View {
            ZStack {
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.loopGreen).frame(width: 5, height: 5)
                        Text("BG").font(.system(size: 12)).foregroundColor(.loopGreen)
                    }
                    .frame(width: 44)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.loopYellow).frame(width: 5, height: 5)
                        Text("COB").font(.system(size: 12)).foregroundColor(.loopYellow)
                    }
                    .frame(width: 44)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.uam).frame(width: 5, height: 5)
                        Text("UAM")
                            .font(.system(size: 12)).foregroundColor(.uam)
                    }
                    .frame(width: 44)

                    Spacer()

                    loopView
                        .offset(x: 0, y: 0)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.insulin).frame(width: 5, height: 5)
                        Text("IOB").font(.system(size: 12)).foregroundColor(.insulin)
                    }
                    .frame(width: 44)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.zt).frame(width: 5, height: 5)
                        Text("ZT").font(.system(size: 12)).foregroundColor(.zt)
                    }
                    .frame(width: 44)

                    Spacer()
                    HStack(spacing: 4) {
                        if let eventualBG = state.eventualBG {
                            if Decimal(state.eventualBG!) > state.highGlucose {
                                Text(
                                    "⇢ " + targetFormatter.string(
                                        from: (state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                                    )!
                                )
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.loopYellow)
                            } else if Decimal(state.eventualBG!) < state.lowGlucose {
                                Text(
                                    "⇢ " + targetFormatter.string(
                                        from: (state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                                    )!
                                )
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.loopRed)
                            } else {
                                Text(
                                    "⇢ " + targetFormatter.string(
                                        from: (state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                                    )!
                                )
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.loopGreen)
                            }
                        }
                    }
                    .frame(width: 44)
                    .onTapGesture {
                        isStatusPopupPresented.toggle()
                    }
                }
                .padding(.bottom, 20)
                .padding(.top, 8)
                .padding(.leading, 10)
                .padding(.trailing, 10)
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
            // .padding(.bottom, 2)
            .modal(for: .dataTable, from: self)
            .background(
                colorScheme == .dark ? Color.black.opacity(0.5) :
                    Color.white
            )
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

        @ViewBuilder private func bottomPanel(_: GeometryProxy) -> some View {
            ZStack {
                Rectangle().fill(
                    colorScheme == .dark ? Color.basal.opacity(0.3) : Color.white
                )
                .frame(height: 87)
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.33 : 0.33),
                    radius: colorScheme == .dark ? 5 : 3
                )
                /* .cornerRadius(10)
                 .shadow(
                     color: Color.black.opacity(colorScheme == .dark ? 0.75 : 0.33),
                     radius: colorScheme == .dark ? 5 : 3
                 )
                 .padding([.leading, .trailing], 10) */

                HStack {
                    Button { state.showModal(for: .addCarbs(editMode: false, override: false)) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image("carbs")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 27, height: 27)
                                .foregroundColor(.loopYellow)
                                .padding(.top, 20)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                            if state.carbsRequired != nil {
                                /* Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                 .font(.caption2)
                                 .foregroundColor(.white)
                                 .padding(2)
                                 .background(Capsule().fill(Color.purple)) */
                                Circle().fill(Color.purple).frame(width: 6, height: 6)
                                    .offset(x: -19.33, y: 4)
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
                                .padding(.top, 18)
                                .padding(.bottom, 6)
                                .padding(.leading, 9)
                                .padding(.trailing, 6)
                            if state.tempTarget != nil {
                                /* Image(systemName: "timer")
                                 .font(.caption2)
                                 .foregroundColor(.white)
                                 .padding(2)
                                 .background(Capsule().fill(Color.purple)) */
                                Circle().fill(Color.purple).frame(width: 6, height: 6)
                                    .offset(x: -21, y: 4)
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
                                .padding(.top, 20)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)

                            if let insulinRequested = state.suggestion?.insulinReq, insulinRequested > 0.3 {
                                /* Image(systemName: "plus.circle")
                                 .font(.caption2)
                                 .foregroundColor(.white)
                                 .padding(2)
                                 .background(Capsule().fill(Color.purple)) */
                                Circle().fill(Color.purple).frame(width: 6, height: 6)
                                    .offset(x: -19.33, y: 4)
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
                                .padding(.top, 20)
                                .padding(.bottom, 7)
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
                                .padding(.top, 20)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                            if selectedProfile().isOn {
                                /* Image(systemName: "person.fill")
                                 .font(.caption2)
                                 .foregroundColor(.white)
                                 .padding(2)
                                 .background(Capsule().fill(Color.purple)) */
                                Circle().fill(Color.purple).frame(width: 6, height: 6)
                                    .offset(x: -19.33, y: 4)
                            }
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    Button { state.showModal(for: .settings) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image("settings1")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 27, height: 27)
                                .padding(.top, 20)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                                .foregroundColor(.gray)
                            if state.closedLoop && state.settingsManager.preferences.maxIOB == 0 || state.pumpSuspended == true {
                                Circle().fill(Color.purple).frame(width: 6, height: 6)
                                    .offset(x: -19.33, y: 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 25)
            }
        }

        var body: some View {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    header(geo)
                    infoPanel
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                        .overlay(mainChart)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.75 : 0.33),
                            radius: colorScheme == .dark ? 5 : 3
                        )
                        .padding(.horizontal, 10)
                        .frame(maxHeight: UIScreen.main.bounds.height / 2.2)
                    timeInterval
                    legendPanel
                    bottomPanel(geo)
                }
                .edgesIgnoringSafeArea(.all)
            }
            .onChange(of: state.hours) { _ in
                highlightButtons()
            }
            .onAppear {
                configureView {
                    highlightButtons()
                }
            }
            .background(Color.blue.opacity(0.12))
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
