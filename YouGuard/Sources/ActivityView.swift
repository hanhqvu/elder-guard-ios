//
//  ActivityView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import SwiftUI

// MARK: - Person Model

struct Person: Identifiable {
	let id = UUID()
	let name: String
	let imageName: String
	let gender: String
	let age: Int
}

// MARK: - Activity View

struct ActivityView: View {
	private let people: [Person] = [
		Person(name: "Hanh", imageName: "hanh", gender: "Nam", age: 27),
		Person(name: "Nicola", imageName: "nicola", gender: "Nam", age: 39)
	]

	var body: some View {
		NavigationStack {
			List(people) { person in
				NavigationLink(destination: ActivityDetailView(
					personName: person.name,
					personGender: person.gender,
					personAge: person.age
				)) {
					PersonRowView(person: person)
				}
			}
			.navigationTitle("Theo dõi hoạt động")
		}
	}
}

// MARK: - Person Row View

struct PersonRowView: View {
	let person: Person

	var body: some View {
		HStack(spacing: 15) {
			// Profile Image
			Image(person.imageName)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.frame(width: 60, height: 60)
				.clipShape(Circle())

			// Person Info
			VStack(alignment: .leading, spacing: 4) {
				Text(person.name)
					.font(.headline)
				Text("\(person.gender), \(person.age) tuổi")
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
		}
		.padding(.vertical, 8)
	}
}

#Preview {
	NavigationStack {
		ActivityView()
	}
}
