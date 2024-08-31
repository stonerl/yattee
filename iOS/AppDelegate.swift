import AVFoundation
import Foundation
import Logging
import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var orientationLock = UIInterfaceOrientationMask.all

    private var logger = Logger(label: "stream.yattee.app.delegalate")
    private(set) static var instance: AppDelegate!

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        orientationLock
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool { // swiftlint:disable:this discouraged_optional_collection
        Self.instance = self

        #if !os(macOS)
            UIViewController.swizzleHomeIndicatorProperty()
            OrientationTracker.shared.startDeviceOrientationTracking()

            // Configure the audio session for playback
            do {
                // .mixWithOthers is needed for Audio Ducking and only works with mode: .default
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            } catch {
                logger.error("Failed to set audio session category: \(error)")
            }

            // Begin receiving remote control events
            UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif

        return true
    }

    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.scheme == "yattee" {
            OpenURLHandler(navigationStyle: Constants.defaultNavigationStyle).handle(url)
            return true
        }
        return false
    }
}
