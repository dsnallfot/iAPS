import CoreData
import SpriteKit
import SwiftDate
import SwiftUI
import Swinject
import WebKit

extension Home {
    // WebViewRepresentable to wrap a WKWebView
    struct WebViewRepresentable: UIViewControllerRepresentable {
        let urlString: String

        func makeUIViewController(context: Context) -> UIViewController {
            let viewController = UIViewController()
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator
            viewController.view = webView

            if let url = URL(string: urlString) {
                let request = URLRequest(url: url)
                webView.load(request)
            }

            // Disable scrolling
            webView.scrollView.isScrollEnabled = false

            return viewController
        }

        func updateUIViewController(_: UIViewController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            var parent: WebViewRepresentable

            init(_ parent: WebViewRepresentable) {
                self.parent = parent
            }
        }
    }

    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state = StateModel()
        @State var isStatusPopupPresented = false
        @State var showCancelAlert = false
        @State var showCancelTTAlert = false

        struct Buttons: Identifiable {
            let label: String
            let number: String
            var active: Bool
            let hours: Int16
            var id: String { label }
        }

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

        @ViewBuilder func header(_: GeometryProxy) -> some View {
            ZStack {
                VStack(alignment: .center) {
                    HStack(alignment: .center) {
                        let gradient = LinearGradient(gradient: Gradient(colors: [
                            Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                            Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                            Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                            Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                            Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                        ]), startPoint: .leading, endPoint: .trailing)

                        Text("iAPS Caregiver Remote")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .overlay(
                                gradient
                                    .mask(
                                        Text("iAPS Caregiver Remote")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
            .padding(.bottom, 14)
        }

        @ViewBuilder private func webNightscout(_: GeometryProxy) -> some View {
            ZStack {
                VStack {
                    HStack(alignment: .center) {
                        Spacer()
                        HStack(alignment: .center) {
                            Button {
                                UIApplication.shared.open(
                                    URL(
                                        string: "shortcuts://run-shortcut?name=Remote%20Dextro"
                                    )!,
                                    options: [:],
                                    completionHandler: nil
                                )
                            }
                            label: {
                                Image(systemName: "pills.fill")
                                    .renderingMode(.template)
                                    .frame(width: 12, height: 12)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 25, height: 25)

                            .background(Color(red: 0.20, green: 0.20, blue: 0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .padding(.top, 8)

                        HStack(alignment: .center) {
                            Button {
                                UIApplication.shared.open(
                                    URL(
                                        string: "shortcuts://run-shortcut?name=Hälsologgning"
                                    )!,
                                    options: [:],
                                    completionHandler: nil
                                )
                            }
                            label: {
                                Image(systemName: "calendar.badge.plus")
                                    .renderingMode(.template)
                                    .frame(width: 12, height: 12)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 25, height: 25)

                            .background(Color(red: 0.20, green: 0.20, blue: 0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .padding(.top, 8)
                        .padding(.trailing, 104)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .zIndex(1)
                VStack {
                    // Use WebViewRepresentable to display the webpage
                    WebViewRepresentable(
                        urlString: "https://ivarsnightscout.herokuapp.com" // state.url // dont get this to work in home view
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .zIndex(0)
            }
        }

        @ViewBuilder private func bottomPanel(_: GeometryProxy) -> some View {
            ZStack {
                Rectangle().fill(
                    colorScheme == .dark ? Color.loopGray.opacity(0.1) : Color.white
                )
                .frame(height: 80)
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0 : 0.5),
                    radius: colorScheme == .dark ? 1 : 1
                )
                let isOverride = fetchedPercent.first?.enabled ?? false
                let isTarget = (state.tempTarget != nil)

                HStack {
                    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                        Image(systemName: "fork.knife")
                            .renderingMode(.template)
                            .frame(width: 27, height: 27)
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(state.disco ? .loopYellow : .gray)
                            .padding(.top, 14)
                            .padding(.bottom, 9)
                            .padding(.leading, 7)
                            .padding(.trailing, 7)
                            .onTapGesture {
                                state.showModal(for: .addCarbs(editMode: false, override: false))
                            }
                            .onLongPressGesture {
                                UIApplication.shared.open(
                                    URL(
                                        string: "shortcuts://run-shortcut?name=Remote%20Kolhydrater" // Använd med "Öppna app iAPS Caregiver" som första åtgärd i shortcut Remote Måltid ist för x-callback
                                        /* string: "shortcuts://x-callback-url/run-shortcut?name=Remote%20Måltid&x-success=ivaraps://&x-cancel=ivaraps://&x-error=ivaraps://" */
                                    )!,
                                    options: [:],
                                    completionHandler: nil
                                )
                            }
                    }.buttonStyle(.plain)

                    /* Button { state.showModal(for: .addCarbs(editMode: false, override: false)) }
                     label: {
                     ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                     Image(systemName: "fork.knife")
                     .renderingMode(.template)
                     .frame(width: 27, height: 27)
                     .font(.system(size: 24, weight: .regular))
                     .foregroundColor(state.disco ? .loopYellow : .gray)
                     .padding(.top, 14)
                     .padding(.bottom, 9)
                     .padding(.leading, 7)
                     .padding(.trailing, 7)
                     if state.carbsRequired != nil {
                     Circle().fill(state.disco ? Color.loopYellow : Color.gray).frame(width: 6, height: 6)
                     .offset(x: 1, y: 2.5)
                     }
                     }
                     }.buttonStyle(.plain) */

                    Spacer()
                    Button {
                        UIApplication.shared.open(
                            URL(
                                string: "shortcuts://run-shortcut?name=Remote%20Bolus" // Använd med "Öppna app iAPS Caregiver" som första åtgärd i shortcut Remote Bolus ist för x-callback
                                /* string: "shortcuts://x-callback-url/run-shortcut?name=Remote%20Bolus&x-success=ivaraps://&x-cancel=ivaraps://&x-error=ivaraps://" */
                            )!,
                            options: [:],
                            completionHandler: nil
                        )
                    } label: {
                        Image(systemName: "drop")
                            .renderingMode(.template)
                            .frame(width: 27, height: 27)
                            .font(.system(size: 27, weight: .regular))
                            .foregroundColor(state.disco ? .insulin : .gray)
                            .padding(.top, 13)
                            .padding(.bottom, 7)
                            .padding(.leading, 7)
                            .padding(.trailing, 7)
                    }

                    Spacer()

                    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                        Image(systemName: "target")
                            .renderingMode(.template)
                            .frame(width: 27, height: 27)
                            .font(.system(size: 27, weight: .light))
                            .foregroundColor(state.disco ? .cyan : .gray)
                            .padding(.top, 13)
                            .padding(.bottom, 7)
                            .padding(.leading, 7)
                            .padding(.trailing, 7)
                            .onTapGesture {
                                if isTarget {
                                    showCancelTTAlert.toggle()
                                } else {
                                    state.showModal(for: .addTempTarget)
                                }
                            }
                            .onLongPressGesture {
                                state.showModal(for: .addTempTarget)
                            }
                        if state.tempTarget != nil {
                            Circle().fill(state.disco ? Color.cyan : Color.gray).frame(width: 6, height: 6)
                                .offset(x: 0, y: 4)
                        }
                    }.buttonStyle(.plain)

                    Spacer()

                    Button {
                        UIApplication.shared.open(
                            URL(
                                string: "shortcuts://run-shortcut?name=Remote%20Override" // Använd med "Öppna app iAPS Caregiver" som första åtgärd i shortcut Remote Override ist för x-callback
                                /* string: "shortcuts://x-callback-url/run-shortcut?name=Remote%20Override&x-success=ivaraps://&x-cancel=ivaraps://&x-error=ivaraps://" */
                            )!,
                            options: [:],
                            completionHandler: nil
                        )

                        // state.showModal(for: .overrideProfilesConfig)
                    }
                    label: {
                        // ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                        Image(systemName: "person")
                            .renderingMode(.template)
                            .frame(width: 27, height: 27)
                            .font(.system(size: 27, weight: .regular))
                            .foregroundColor(state.disco ? .purple.opacity(0.7) : .gray)
                            .padding(.top, 13)
                            .padding(.bottom, 7)
                            .padding(.leading, 7)
                            .padding(.trailing, 7)
                        /* if selectedProfile().isOn {
                         Circle().fill(state.disco ? Color.purple.opacity(0.7) : Color.gray).frame(width: 6, height: 6)
                         .offset(x: 0, y: 4)
                         } */
                        // }
                    }.buttonStyle(.plain)
                    Spacer()
                    Button { state.secureShowSettings() }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                            Image(systemName: "gearshape")
                                // Image("settings1")
                                .renderingMode(.template)
                                // .resizable()
                                .frame(width: 27, height: 27)
                                .font(.system(size: 27, weight: .regular))
                                .padding(.top, 13)
                                .padding(.bottom, 7)
                                .padding(.leading, 7)
                                .padding(.trailing, 7)
                                .foregroundColor(state.disco ? .gray : .gray)
                            if state.closedLoop && state.settingsManager.preferences.maxIOB == 0 || state.pumpSuspended == true {
                                Circle().fill(state.disco ? Color.gray : Color.gray).frame(width: 6, height: 6)
                                    .offset(x: 0, y: 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            /* .confirmationDialog("Avbryt override", isPresented: $showCancelAlert) {
             Button("Avbryt override", role: .destructive) {
             state.cancelProfile()
             triggerUpdate.toggle()
             }
             } */
            .confirmationDialog("Avbryt tillfälligt mål", isPresented: $showCancelTTAlert) {
                Button("Avbryt tillfälligt mål", role: .destructive) {
                    state.cancelTempTargets()
                }
            }
        }

        var body: some View {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    header(geo)
                    webNightscout(geo)
                    bottomPanel(geo)
                }
                .edgesIgnoringSafeArea(.all)
            }
            .onAppear {
                configureView {}
            }
            .background(Color.loopGray.opacity(0.0)) // 12))
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .onDisappear {
                state.saveSettings()
            }
        }
    }
}
