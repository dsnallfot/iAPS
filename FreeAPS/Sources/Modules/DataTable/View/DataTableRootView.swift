import CoreData
import SwiftUI
import Swinject

extension DataTable {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @State private var isRemoveCarbsAlertPresented = false
        @State private var removeCarbsAlert: Alert?
        @State private var isRemoveInsulinAlertPresented = false
        @State private var removeInsulinAlert: Alert?
        @State private var newGlucose = false

        @Environment(\.colorScheme) var colorScheme

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
            }
            formatter.roundingMode = .halfUp
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter
        }

        var body: some View {
            VStack {
                Picker("Mode", selection: $state.mode) {
                    ForEach(Mode.allCases.indexed(), id: \.1) { index, item in
                        Text(item.name).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                Form {
                    switch state.mode {
                    case .treatments: treatmentsList
                    case .basals: basalsList
                    case .glucose: glucoseList
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(
                leading: Button("Close", action: state.hideModal),
                trailing: HStack {
                    if state.mode == .glucose && !newGlucose {
                        Button(action: { newGlucose = true }) {
                            Text("")
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                            Spacer()
                        }
                    }
                }
            )
            .popup(isPresented: newGlucose, alignment: .top, direction: .bottom) {
                VStack {
                    HStack {
                        Text("Blodsocker")
                        DecimalTextField(" ... ", value: $state.manualGlcuose, formatter: glucoseFormatter)
                        Text(state.units.rawValue)
                    }.padding(.horizontal, 20)
                    HStack {
                        let limitLow: Decimal = state.units == .mmolL ? 2.2 : 40
                        let limitHigh: Decimal = state.units == .mmolL ? 21 : 380
                        Button { newGlucose = false }
                        label: { Text("Cancel") }.frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            state.addManualGlucose()
                            newGlucose = false
                        }
                        label: { Text("Save") }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .disabled(state.manualGlcuose < limitLow || state.manualGlcuose > limitHigh)

                    }.padding(20)
                }
                .frame(maxHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(colorScheme == .dark ? UIColor.systemGray2 : UIColor.systemGray6))
                )
            }
        }

        private var treatmentsList: some View {
            List {
                ForEach(state.treatments) { item in
                    treatmentView(item)
                }
                .onDelete(perform: deleteTreatment)
            }
        }

        private var basalsList: some View {
            List {
                ForEach(state.basals) { item in
                    basalView(item)
                }
                .onDelete(perform: deleteMeal)
            }
        }

        private var glucoseList: some View {
            List {
                ForEach(state.glucose) { item in
                    glucoseView(item)
                }
                .onDelete(perform: deleteGlucose)
            }
        }

        @ViewBuilder private func treatmentView(_ item: Treatment) -> some View {
            HStack {
                Text((item.isSMB ?? false) ? "SMB" : item.type.name)
                Text(item.amountText).foregroundColor(.secondary)

                if let duration = item.durationText {
                    Text(duration).foregroundColor(.secondary)
                }

                if item.type == .carbs {
                    if item.note != "" {
                        Text(item.note ?? "").foregroundColor(.brown)
                    }
                }
                Spacer()

                Text(dateFormatter.string(from: item.date))
                    .moveDisabled(true)
            }
        }

        @ViewBuilder private func basalView(_ tempBasal: Treatment) -> some View {
            HStack {
                Text(tempBasal.type.name)
                Text(tempBasal.amountText).foregroundColor(.secondary)

                if let duration = tempBasal.durationText {
                    Text(duration).foregroundColor(.secondary)
                }

                Spacer()

                Text(dateFormatter.string(from: tempBasal.date))
                    .moveDisabled(true)
            }
        }

        @ViewBuilder private func glucoseView(_ item: Glucose) -> some View {
            HStack {
                Text(item.glucose.glucose.map {
                    glucoseFormatter.string(from: Double(
                        state.units == .mmolL ? $0.asMmolL : Decimal($0)
                    ) as NSNumber)!
                } ?? "--")
                Text(state.units.rawValue)
                Text(item.glucose.direction?.symbol ?? "--")

                Spacer()

                Text(dateFormatter.string(from: item.glucose.dateString))
            }
        }

        private func deleteTreatment(at offsets: IndexSet) {
            state.deleteInsulin(at: offsets[offsets.startIndex])
        }

        private func deleteMeal(at offsets: IndexSet) {
            state.deleteCarbs(at: offsets[offsets.startIndex])
        }

        private func deleteGlucose(at offsets: IndexSet) {
            state.deleteGlucose(at: offsets[offsets.startIndex])
        }
    }
}
