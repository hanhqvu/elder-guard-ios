import SwiftUI

struct TabNavigationView: View {
	var body: some View {
		TabView {
			Tab {}

			Tab {}
		}
	}
}

#Preview {
	TabNavigationView()
}
