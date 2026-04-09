import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        AppTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FreshliItem.self, SharedListing.self, UserProfile.self], inMemory: true)
}
