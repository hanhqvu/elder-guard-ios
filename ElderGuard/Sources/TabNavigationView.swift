import SwiftUI

enum AppTab: String {
	case home
	case alert
	case activity
}

struct TabNavigationView: View {
	@State private var selectedTab: AppTab = .home

	var body: some View {
		TabView(selection: $selectedTab) {
			Tab("Alert", systemImage: "bell.fill", value: .alert) {
				AlertListView()
			}

			Tab("Home", systemImage: "house.fill", value: .home) {
				HomeView()
			}

			Tab("Activity", systemImage: "list.bullet", value: .activity) {
				ActivityView()
			}
		}
	}
}

#Preview {
	TabNavigationView()
}
