import SwiftUI

public struct TabNavigationView: View {
    public init() {}

    public var body: some View {
        TabView {
            Tab {}

            Tab {}
        }
    }
}

struct MainViewPreview: PreviewProvider {
    static var previews: some View {
        TabNavigationView()
    }
}
