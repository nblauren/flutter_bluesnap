#import "FlutterBluesnapPlugin.h"
#if __has_include(<flutter_bluesnap/flutter_bluesnap-Swift.h>)
#import <flutter_bluesnap/flutter_bluesnap-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_bluesnap-Swift.h"
#endif

@implementation FlutterBluesnapPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterBluesnapPlugin registerWithRegistrar:registrar];
}
@end
