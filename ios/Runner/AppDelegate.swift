import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS: Flutter 3.41+ Metal'de Skia opt-out desteklenmiyor; iPhone/iPad → Impeller.
    // Android'de TV/tablet Skia, telefon Impeller ([MinaRendererPolicy]).
    let idiom = UIDevice.current.userInterfaceIdiom
    let label = idiom == .phone ? "Impeller (phone)" : "Impeller (pad/tv — Skia N/A on Metal)"
    NSLog("[MinaRenderer] iOS idiom=%@ renderer=%@", idiom == .phone ? "phone" : "pad", label)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "mina_iptv_thermal")!
    let channel = FlutterEventChannel(
      name: "mina_iptv/thermal_state",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(MinaThermalStreamHandler())
  }
}

/// ProcessInfo termal durumu — Dart [EventChannel] ile mpv/OSD optimizasyonu.
private final class MinaThermalStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var token: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    events(Self.map(ProcessInfo.processInfo.thermalState))
    token = NotificationCenter.default.addObserver(
      forName: ProcessInfo.thermalStateDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.sink?(Self.map(ProcessInfo.processInfo.thermalState))
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let t = token {
      NotificationCenter.default.removeObserver(t)
    }
    token = nil
    sink = nil
    return nil
  }

  private static func map(_ state: ProcessInfo.ThermalState) -> Int {
    switch state {
    case .nominal:
      return 0
    case .fair:
      return 1
    case .serious:
      return 2
    case .critical:
      return 3
    @unknown default:
      return 0
    }
  }
}
