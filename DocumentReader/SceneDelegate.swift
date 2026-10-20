import UIKit


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?


    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: ViewController())
        window.tintColor = IXColor.accent
        window.backgroundColor = IXColor.bg
        window.makeKeyAndVisible()
        self.window = window
        if #available(iOS 13.0, *) {
            window.overrideUserInterfaceStyle = .light
        }
    }
}


enum IXColor {
    static let bg = UIColor(red: 0.902, green: 0.914, blue: 0.937, alpha: 1)      // #E6E9EF
    static let text = UIColor(red: 0.078, green: 0.102, blue: 0.133, alpha: 1)     // #141A22
    static let muted = UIColor(red: 0.353, green: 0.396, blue: 0.451, alpha: 1)    // #5A6573
    static let accent = UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1)   // #0F766E
    static let accentDim = UIColor(red: 0.043, green: 0.310, blue: 0.290, alpha: 1) // #0B4F4A
    static let purple = UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1)
    static let surface = UIColor(red: 0.969, green: 0.973, blue: 0.980, alpha: 1)  // #F7F8FA
    static let stroke = UIColor(red: 0.773, green: 0.800, blue: 0.847, alpha: 1)   // #C5CCD8
    static let statusOk = UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1)
    static let statusError = UIColor(red: 0.725, green: 0.110, blue: 0.110, alpha: 1)
    static let statusInfo = UIColor(red: 0.043, green: 0.310, blue: 0.290, alpha: 1)
    static let overlay = UIColor(red: 0.902, green: 0.914, blue: 0.937, alpha: 0.88)
    static let onAccent = UIColor(red: 0.957, green: 1.0, blue: 0.988, alpha: 1)   // #F4FFFC
}
