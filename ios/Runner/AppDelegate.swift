import Flutter
import UIKit
import UserNotifications
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let ringtoneChannel = FlutterMethodChannel(
        name: "com.infiniquote.app/ringtone",
        binaryMessenger: controller.binaryMessenger
      )
      ringtoneChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "getDefaultRingtoneUri":
          result("assets/alarm.mp3")
        case "getRingtoneTitle":
          result("Default Chime")
        case "pickAlarmRingtone":
          result([
            "uri": "assets/alarm.mp3",
            "title": "Default Chime",
            "localPath": ""
          ])
        case "playRingtone", "previewRingtone":
          AudioServicesPlaySystemSound(1005)
          result(true)
        case "stopRingtone", "cancelVibration", "setAlarmRingingState":
          result(true)
        case "triggerVibration":
          AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
          result(true)
        case "canUseFullScreenIntent", "requestFullScreenIntentPermission":
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
