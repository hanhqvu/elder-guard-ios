//
//  HomeView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import SwiftUI

struct HomeView: View {
	@State private var isLivingRoomExpanded = true
	@State private var isBedroomExpanded = false
	@State private var isAudioEnabled = false

	var body: some View {
		ScrollView {
			DisclosureGroup(isExpanded: $isLivingRoomExpanded) {
				VStack(spacing: 16) {
					WebRTCStreamView()
						.frame(height: 250)
						.frame(maxWidth: .infinity)
						.clipShape(RoundedRectangle(cornerRadius: 12))

					Button {
						withAnimation(.easeInOut(duration: 0.3)) {
							isAudioEnabled.toggle()
						}
					} label: {
						Circle()
							.fill(isAudioEnabled ? Color.green : Color.gray)
							.frame(width: 48, height: 48)
							.overlay {
								Image(systemName: isAudioEnabled ? "mic.fill" : "mic.slash.fill")
									.font(.system(size: 20))
									.foregroundStyle(.white)
							}
							.opacity(isAudioEnabled ? 1.0 : 0.6)
					}
				}
				.padding(.vertical, 8)
			} label: {
				HStack {
					Image(systemName: "sofa.fill")
						.foregroundStyle(.blue)
					Text("Phòng khách")
						.font(.headline)
				}
			}

			DisclosureGroup(isExpanded: $isBedroomExpanded) {
				VStack(spacing: 16) {
					WebRTCStreamView()
						.frame(height: 250)
						.frame(maxWidth: .infinity)
						.clipShape(RoundedRectangle(cornerRadius: 12))

					Button {
						withAnimation(.easeInOut(duration: 0.3)) {
							isAudioEnabled.toggle()
						}
					} label: {
						Circle()
							.fill(isAudioEnabled ? Color.green : Color.gray)
							.frame(width: 48, height: 48)
							.overlay {
								Image(systemName: isAudioEnabled ? "mic.fill" : "mic.slash.fill")
									.font(.system(size: 20))
									.foregroundStyle(.white)
							}
							.opacity(isAudioEnabled ? 1.0 : 0.6)
					}
				}
				.padding(.vertical, 8)
			} label: {
				HStack {
					Image(systemName: "bed.double.fill")
						.foregroundStyle(.teal)
					Text("Phòng ngủ")
						.font(.headline)
				}
			}
		}
		.padding()
	}
}

#Preview {
	HomeView()
}
