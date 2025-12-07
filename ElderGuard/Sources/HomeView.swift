//
//  HomeView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import SwiftUI

struct HomeView: View {
	var body: some View {
		VStack {
			WebRTCStreamView()
				.frame(height: 250)
				.clipShape(RoundedRectangle(cornerRadius: 12))
				.padding()

			Spacer()
		}
	}
}

#Preview {
	HomeView()
}
