import SwiftUI

@available(watchOSApplicationExtension 9.0, *)
@main struct FreeAPSApp: App {
    @StateObject var state = WatchStateModel()

    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                MainView()
            }.environmentObject(state)
        }

//        WKNotificationScene(controller: NotificationController.self, category: "FreeAPSCategory")
    }
}
