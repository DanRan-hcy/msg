import SwiftUI

@main
struct PickupApp: App {
    var body: some Scene {
        WindowGroup {
            PickupRootView()
        }
        .modelContainer(PickupStore.container)
    }
}
