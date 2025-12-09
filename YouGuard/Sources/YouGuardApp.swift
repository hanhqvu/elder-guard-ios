import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		UNUserNotificationCenter.current().delegate = self
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
			if granted {
				DispatchQueue.main.async {
					application.registerForRemoteNotifications()
				}
			}
			if let error = error {
				print("Notification authorization error: \(error)")
			}
		}
		return true
	}

	func application(
		_: UIApplication,
		didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
	) {
		let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
		print("📱 Remote notification token: \(token)")
	}

	func application(
		_: UIApplication,
		didFailToRegisterForRemoteNotificationsWithError error: Error
	) {
		print("❌ Failed to register for remote notifications: \(error)")
	}

	func userNotificationCenter(
		_: UNUserNotificationCenter,
		willPresent _: UNNotification,
		withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
	) {
		completionHandler([.banner, .sound, .badge])
	}

	func applicationWillTerminate(_: UIApplication) {
		Task { @MainActor in
			WebRTCConnectionManager.shared.disconnect()
		}
	}
}

@main
struct YouGuardApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	var body: some Scene {
		WindowGroup {
			TabNavigationView()
		}
	}
}
