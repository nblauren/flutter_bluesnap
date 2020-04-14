# BlueSnap Native SDK implementation for Flutter

A plugin to enable use of BlueSnap native SDK implementation for Flutter projects.

## Basic usage

Please see [example project]https://github.com/blidzco/flutter_bluesnap/tree/master/example for basic usage example. Note that you'll have to implement your
own backend for handling BlueSnap Payments API. See BlueSnap documents for details.

https://developers.bluesnap.com

## Limitations

Currently plugin supports only Checkout process and is limited to BlueSnap native UI which will work only on Android and iOS.

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

## How to enable on Anrdoid

On android you'll have to update your apps `minSdkVersion` to 19 within build.gradle.