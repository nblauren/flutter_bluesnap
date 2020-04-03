# BlueSnap Native SDK Plugin usage example for Flutter

Demonstrates how to use the flutter_bluesnap plugin.

## Basic initialization

```
// Note that this dummyToken will only work against testing.
// Within production environment you'll have to get your token
// from your backend implementation.
String dummyToken = await FlutterBluesnap.generateDummyToken(
    bsSandboxUser: [BlueSnap Sandbox Username],
    bsSandboxPw: [BlueSnap Sandbox Password]);

// 3DS does not work with Sandbox tokens
await FlutterBluesnap.setup(token: dummyToken, disable3DS: true);
```

## How to enable on iOS

BlueSnap implementation on iOS is dependant on UINavigation which is not enabled by default in flutter projects. For this reason Flutter iOS platform has to
be initialized a bit differently:

[From example project]https://github.com/blidzco/flutter_bluesnap/blob/master/example/ios/Runner/AppDelegate.swift

When using default Flutter implementation you'll need to add following code to application method of your `application` method within `AppDelegate.swift`

```
self.navigationController = UINavigationController(rootViewController: flutterViewController);
self.navigationController?.setNavigationBarHidden(true, animated: false);

self.window = UIWindow(frame: UIScreen.main.bounds);
self.window.rootViewController = self.navigationController;
self.window.makeKeyAndVisible()
```