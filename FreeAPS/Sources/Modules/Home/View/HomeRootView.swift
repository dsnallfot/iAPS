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

        let buttonFont = Font.custom("TimeButtonFont", size: 14)

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
            let colour: Color = colorScheme == .dark ? .black : .white
            HStack(alignment: .bottom) {
                Spacer()
                cobIobView
                Spacer()
                glucoseView
                Spacer()
                pumpView
                Spacer()
                loopView
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10 + geo.safeAreaInsets.top)
            .padding(.bottom, 10)
            .background(Color.gray.opacity(0.3))

            Rectangle().fill(colour).frame(maxHeight: 1)
        }

        var cobIobView: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("IOB: ")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(
                        (numberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0") +
                            NSLocalizedString(" U", comment: "Insulin unit")
                    )
                    .font(.footnote)
                    .fontWeight(.bold)
                }
                .frame(alignment: .top) // Align the whole HStack to the top

                HStack {
                    Text("COB:")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(
                        (numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0") +
                            NSLocalizedString(" g", comment: "gram of carbs")
                    )
                    .font(.footnote)
                    .fontWeight(.bold)
                }
                .frame(alignment: .bottom) // Align the whole HStack to the bottom
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
                    state.openCGM()
                } else {
                    state.showModal(for: .snooze)
                }
            }
            .onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                if state.alarm == nil {
                    state.showModal(for: .snooze)
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
                isStatusPopupPresented = true
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
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.loopGray)
                        .padding(.leading, 8)
                } else if let tempBasalString = tempBasalString {
                    Text(tempBasalString)
                        .font(.system(size: 12, weight: .bold))
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
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.cyan)
                        Text(overrideString)
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                            .padding(.trailing, 8)
                    }
                }

                if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                    (Text(Image(systemName: "x.circle")) + Text(" Max IOB: 0!"))
                        .font(.callout)
                        .foregroundColor(.red)
                        .padding(.trailing, 8)
                }

                if let progress = state.bolusProgress {
                    HStack {
                        Text("Bolusing")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.insulin)
                        ProgressView(value: Double(progress))
                            .progressViewStyle(BolusProgressViewStyle())
                            .padding(.trailing, 8)
                    }
                    .onTapGesture {
                        state.cancelBolus()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 50)
            .background(Color.gray.opacity(0.22))
        }

        var timeInterval: some View {
            HStack(alignment: .center) {
                let saveButton = UXSettings(context: moc)
                ForEach(timeButtons) { button in
                    Text(button.active ? NSLocalizedString(button.label, comment: "") : button.number).onTapGesture {
                        let index = timeButtons.firstIndex(where: { $0.label == button.label }) ?? 0
                        highlightButtons(index, onAppear: false)
                        saveButton.hours = button.hours
                        saveButton.date = Date.now
                        try? moc.save()
                        state.hours = button.hours
                    }
                    .foregroundStyle(button.active ? .primary : .secondary)
                    .frame(maxHeight: 20).padding(.horizontal)
                    .background(button.active ? Color(.systemGray5) : .clear, in: .capsule(style: .circular))
                }
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(.secondary)
                    .padding(.leading)
                    .onTapGesture {
                        state.showModal(for: .statisticsConfig)
                    }
            }
            .font(buttonFont)
            .padding(.top, 5)
            .padding(.bottom, 20)
        }

        var legendPanel: some View {
            ZStack {
                HStack(alignment: .center) {
                    Group {
                        Circle().fill(Color.loopGreen).frame(width: 8, height: 8)
                        Text("BG")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.loopGreen)
                    }
                    Group {
                        Circle().fill(Color.insulin).frame(width: 8, height: 8)
                            .padding(.leading, 8)
                        Text("IOB")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.insulin)
                    }
                    Group {
                        Circle().fill(Color.zt).frame(width: 8, height: 8)
                            .padding(.leading, 8)
                        Text("ZT")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.zt)
                    }
                    Group {
                        Circle().fill(Color.loopYellow).frame(width: 8, height: 8)
                            .padding(.leading, 8)
                        Text("COB")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.loopYellow)
                    }
                    Group {
                        Circle().fill(Color.uam).frame(width: 8, height: 8)
                            .padding(.leading, 8)
                        Text("UAM")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.uam)
                    }

                    if let eventualBG = state.eventualBG {
                        Text(
                            "⇢ " + numberFormatter.string(
                                from: (state.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                            )!
                        )
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding([.bottom], 17)
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

        @ViewBuilder private func profiles(_: GeometryProxy) -> some View {
            let colour: Color = colorScheme == .dark ? .black : .white
            // Rectangle().fill(colour).frame(maxHeight: 1)
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.22)).frame(maxHeight: 50)
                let cancel = fetchedPercent.first?.enabled ?? false
                HStack(spacing: cancel ? 25 : 15) {
                    Button { state.showModal(for: .overrideProfilesConfig) }
                    label: {
                        Text(selectedProfile().name).foregroundColor(.primary)

                        Image(systemName: "person.3.sequence.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                !(fetchedPercent.first?.enabled ?? false) ? .green : .cyan,
                                !(fetchedPercent.first?.enabled ?? false) ? .cyan : .green,
                                .purple
                            )
                    }
                    if cancel, selectedProfile().isOn {
                        Button { showCancelAlert.toggle() }
                        label: {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .alert(
                "Return to Normal?", isPresented: $showCancelAlert,
                actions: {
                    Button("No", role: .cancel) {}
                    Button("Yes", role: .destructive) {
                        state.cancelProfile()
                    }
                }, message: { Text("This will change settings back to your normal profile.") }
            )
            Rectangle().fill(colour).frame(maxHeight: 1)
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

        func highlightButtons(_ int: Int?, onAppear: Bool) {
            var index = 0
            if let integer = int, !onAppear {
                repeat {
                    if index == integer {
                        timeButtons[index].active = true
                    } else {
                        timeButtons[index].active = false
                    }
                    index += 1
                } while index < timeButtons.count
            } else if onAppear {
                let i = timeButtons.firstIndex(where: { $0.hours == (fetchedSettings.first?.hours ?? 6) }) ?? 2
                index = 0
                repeat {
                    if index == i {
                        timeButtons[index].active = true
                    } else {
                        timeButtons[index].active = false
                    }
                    index += 1
                } while index < timeButtons.count
            }
        }

        @ViewBuilder private func bottomPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 54 + geo.safeAreaInsets.bottom)

                /*
                  HStack {
                     Button { state.showModal(for: .addCarbs) }
                     label: {
                         ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                             Image(systemName: "fork.knife.circle")
                                 .renderingMode(.template)
                                 .resizable()
                                 .frame(width: 32, height: 32)
                                 .foregroundColor(.loopYellow)
                                 .padding(8)
                             if let carbsReq = state.carbsRequired {
                                 Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                     .font(.caption)
                                     .foregroundColor(.white)
                                     .padding(3)
                                     .background(Capsule().fill(Color.loopRed))
                             }
                         }
                     }.buttonStyle(.plain)
                     Spacer()
                     Button { state.showModal(for: .addTempTarget) }
                     label: {
                         ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                             Image(systemName: "target")
                                 .renderingMode(.template)
                                 .resizable()
                                 .frame(width: 32, height: 32)
                                 .foregroundColor(.loopGreen)
                                 .padding(8)
                             if state.tempTarget != nil {
                                 Image(systemName: "timer")
                                     .font(.caption)
                                     .foregroundColor(.white)
                                     .padding(3)
                                     .background(Capsule().fill(Color.loopRed))
                             }
                         }
                     }.buttonStyle(.plain)
                     Spacer()
                     Button { state.showModal(for: .bolus(waitForSuggestion: false)) }
                     label: {
                         Image(systemName: "drop.circle")
                             .renderingMode(.template)
                             .resizable()
                             .frame(width: 32, height: 32)
                             .padding(8)
                     }.foregroundColor(.insulin)
                     Spacer()
                     if state.allowManualTemp {
                         Button { state.showModal(for: .manualTempBasal) }
                         label: {
                             Image(systemName: "plus.circle")
                                 .renderingMode(.template)
                                 .resizable()
                                 .frame(width: 32, height: 32)
                                 .padding(8)
                         }.foregroundColor(.insulin)
                         Spacer()
                     }
                     Button { state.showModal(for: .statistics)
                     }
                     label: {
                         Image(systemName: "chart.line.uptrend.xyaxis.circle")
                             .renderingMode(.template)
                             .resizable()
                             .frame(width: 32, height: 32)
                             .padding(8)
                     }.foregroundColor(.purple)
                     Spacer()
                     Button { state.showModal(for: .settings) }
                     label: {
                         Image(systemName: "gearshape.circle")
                             .renderingMode(.template)
                             .resizable()
                             .frame(width: 32, height: 32)
                             .padding(8)
                     }.foregroundColor(.gray)
                 }

                   */
                HStack {
                    Button { state.showModal(for: .addCarbs(editMode: false, override: false)) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image("carbs")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 27, height: 27)
                                .foregroundColor(.loopYellow)
                                .padding(.top, 15)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                            if let carbsReq = state.carbsRequired {
                                Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Capsule().fill(Color.loopRed))
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
                                .padding(.top, 12)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 6)
                            if state.tempTarget != nil {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Capsule().fill(Color.loopRed))
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
                                .padding(.top, 15)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)

                            if let insulinRequested = state.suggestion?.insulinReq, insulinRequested > 0 {
                                // let formattedInsulin = String(format: "%.1f", Double(insulinRequested) as Double)
                                // Text(formattedInsulin)
                                Image(systemName: "plus.circle")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Capsule().fill(Color.loopRed))
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
                                .padding(.top, 15)
                                .padding(.bottom, 7)
                                .padding(.leading, 9)
                                .padding(.trailing, 9)
                        }.foregroundColor(.insulin)
                        Spacer()
                    }
                    Button { state.showModal(for: .statistics)
                    }
                    label: {
                        Image(systemName: "chart.xyaxis.line")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 27, height: 27)
                            .padding(.top, 15)
                            .padding(.bottom, 7)
                            .padding(.leading, 9)
                            .padding(.trailing, 9)
                    }.foregroundColor(.purple)
                    Spacer()
                    Button { state.showModal(for: .settings) }
                    label: {
                        Image("settings1")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 27, height: 27)
                            .padding(.top, 15)
                            .padding(.bottom, 7)
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
                    profiles(geo)
                    bottomPanel(geo)
                }
                .edgesIgnoringSafeArea(.vertical)
            }
            .onAppear {
                configureView {
                    highlightButtons(nil, onAppear: true)
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
                            .fill(Color(UIColor.systemGray3))
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
                Text(state.statusTitle).font(.headline).foregroundColor(.white)
                    .padding(.bottom, 4)
                if let suggestion = state.suggestion {
                    TagCloudView(tags: suggestion.reasonParts).animation(.none, value: false)

                    Text(suggestion.reasonConclusion.capitalizingFirstLetter()).font(.caption).foregroundColor(.white)

                } else {
                    Text("No suggestion found").font(.body).foregroundColor(.white)
                }

                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    Text(NSLocalizedString("Error at", comment: "") + " " + dateFormatter.string(from: date))
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.bottom, 4)
                        .padding(.top, 8)
                    Text(errorMessage).font(.caption).foregroundColor(.loopRed)
                }
            }
        }
    }
}
