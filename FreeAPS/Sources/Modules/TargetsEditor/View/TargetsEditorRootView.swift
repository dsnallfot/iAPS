import SwiftUI
import Swinject

extension TargetsEditor {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var editMode = EditMode.inactive

        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.timeStyle = .short
            return formatter
        }

        private var rateFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        var body: some View {
            Form {
                Section(header: Text("Schedule")) {
                    list
                    addButton
                }
                Section {
                    Button {
                        let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                        impactHeavy.impactOccurred()
                        state.save()
                    }
                    label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .font(.title3)
                    }
                    .disabled(state.items.isEmpty)
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
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Target Glucose")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(
                trailing: EditButton()
            )
            .environment(\.editMode, $editMode)
            .onAppear {
                state.validate()
            }
        }

        private func pickers(for index: Int) -> some View {
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Text("Target").frame(width: geometry.size.width / 3)
                        Text("Time").frame(width: geometry.size.width / 3)
                    }
                    HStack(spacing: 0) {
                        Picker(selection: $state.items[index].lowIndex, label: EmptyView()) {
                            ForEach(0 ..< state.rateValues.count, id: \.self) { i in
                                Text(
                                    self.rateFormatter
                                        .string(from: state.rateValues[i] as NSNumber) ?? ""
                                ).tag(i)
                            }
                        }
                        .frame(maxWidth: geometry.size.width / 3)
                        .clipped()
                        Picker(selection: $state.items[index].timeIndex, label: EmptyView()) {
                            ForEach(0 ..< state.timeValues.count, id: \.self) { i in
                                Text(
                                    self.dateFormatter
                                        .string(from: Date(
                                            timeIntervalSince1970: state
                                                .timeValues[i]
                                        ))
                                ).tag(i)
                            }
                        }
                        .frame(maxWidth: geometry.size.width / 3)
                        .clipped()
                    }
                }
            }
        }

        private var list: some View {
            List {
                ForEach(state.items.indexed(), id: \.1.id) { index, item in
                    NavigationLink(destination: pickers(for: index)) {
                        HStack {
                            Text(
                                "\(rateFormatter.string(from: state.rateValues[item.lowIndex] as NSNumber) ?? "0")"
                            )
                            Text("\(state.units.rawValue)").foregroundColor(.secondary)
                            Spacer()
                            Text("starts at").foregroundColor(.secondary)
                            Text(
                                "\(dateFormatter.string(from: Date(timeIntervalSince1970: state.timeValues[item.timeIndex])))"
                            )
                        }
                    }
                    .moveDisabled(true)
                }
                .onDelete(perform: onDelete)
            }
        }

        private var addButton: some View {
            guard state.canAdd else {
                return AnyView(EmptyView())
            }

            switch editMode {
            case .inactive:
                return AnyView(Button(action: onAdd) { Text("Add") })
            default:
                return AnyView(EmptyView())
            }
        }

        func onAdd() {
            state.add()
        }

        private func onDelete(offsets: IndexSet) {
            state.items.remove(atOffsets: offsets)
            state.validate()
        }
    }
}
