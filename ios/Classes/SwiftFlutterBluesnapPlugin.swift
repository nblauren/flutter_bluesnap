import Flutter
import UIKit
import BluesnapSDK
import os.log

enum BluesnapPluginError: Error {
    case runtimeError(String)
}

class BluesnapNavigationDelegate: NSObject, UINavigationControllerDelegate {
    var bsPlugin:SwiftFlutterBluesnapPlugin?;

    init(plugin: SwiftFlutterBluesnapPlugin) {
        self.bsPlugin = plugin;
    }
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        if (viewController is FlutterViewController) {
            NSLog("Will show Flutter view controller");
            self.bsPlugin?.returningToFlutter();
        }
    }
}

public class SwiftFlutterBluesnapPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterBluesnapPlugin(pluginRegistrar: registrar);

        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel);

    }

    let channelName = "flutter_bluesnap";

    var pluginRegistrar : FlutterPluginRegistrar;
    var methodChannel : FlutterMethodChannel;

    fileprivate var shouldInitKount = true

    var token : BSToken?;
    var currency : String?;
    var applePayMerchantIdentifier : String?;
    var enableApplePay : Bool = false;
    var enablePaypal : Bool = false;
    var disable3DS: Bool = false;

    var viewController:UIViewController?;
    var navigationControllerDelegate:BluesnapNavigationDelegate?;

    init(pluginRegistrar: FlutterPluginRegistrar) {
        self.pluginRegistrar = pluginRegistrar;
        self.methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: pluginRegistrar.messenger());
        super.init();

        self.navigationControllerDelegate = BluesnapNavigationDelegate(plugin: self);
    }

    private func sendMessageToDart(_ name: String, _ value: NSObject? = nil) {
        NSLog("Sending \(name) to app")
        methodChannel.invokeMethod(name, arguments: value) {
            (result: Any?) -> Void in

            if let error = result as? FlutterError {
                NSLog("\(name) failed: %@", error.message!)
            } else if FlutterMethodNotImplemented.isEqual(result) {
                NSLog("\(name) not implemented")
            } else if (result != nil) {
                NSLog("Got response (but it's not used): \(result as! String)");
            }
        }
    }

    /**
     Called by the BlueSnapSDK when token expired error is recognized.
     Here we generate and set a new token, so that when the action re-tries, it will succeed.
     In your real app you should get the token from your app server, then call
     BlueSnapSDK.setBsToken to set it.
     */
    private func requestNewTokenFromDart(completion: @escaping (_ token: BSToken?, _ error: BSErrors?) -> Void) {

        NSLog("Got BS token expiration notification!")

        methodChannel.invokeMethod("getNewToken", arguments: nil) {
            (result: Any?) -> Void in

            if let flutterError = result as? FlutterError {
                NSLog("getNewToken failed: \(flutterError.message!)")
            } else if FlutterMethodNotImplemented.isEqual(result) {
                NSLog("\(result as! String) not implemented")
            } else if (result != nil) {
                NSLog("Got new token: \(result as! String)")
                do {
                    try self.token = BSToken(tokenStr: result as? String);
                } catch {
                    NSLog("Set token failed: \(error)");
                    self.sendMessageToDart("setupFailed", error as NSObject);
                    return;
                }

                do {
                    try BlueSnapSDK.setBsToken(bsToken: self.token)
                    NSLog("Got BS token: \(self.token?.getTokenStr() ?? "")");
                    DispatchQueue.main.async {
                        completion(self.token, nil)
                    }

                } catch {
                    NSLog("Set token failed: \(error)")
                    self.sendMessageToDart("setupFailed", error as NSObject);
                }
            } else {
                NSLog("Set token failed: No token returned");
                self.sendMessageToDart("setupFailed");
            }
        }
    }

    private func sdkSetup() throws {
        do {
            try BlueSnapSDK.initBluesnap(
                bsToken: self.token,
                generateTokenFunc: self.requestNewTokenFromDart,
                initKount: self.shouldInitKount,
                fraudSessionId: nil,
                applePayMerchantIdentifier: self.applePayMerchantIdentifier,
                merchantStoreCurrency: self.currency,
                completion: { error in
                    if let error = error {
                        NSLog("Bluesnap initialization failed: \(error.description())");
                        self.sendMessageToDart("setupFailed", error.description() as NSObject);
                    } else {
                        NSLog("Bluesnap initialization success, inform app.")

                        self.sendMessageToDart("setupComplete");
                    }
            })

        } catch {
            NSLog("Unexpected error: \(error)")
            self.sendMessageToDart("setupFailed", error as NSObject);
            throw error;
        }
    }

    /**
     This is the callback we pass to BlueSnap SDK; it will be called when all the shopper details have been
     enetered, and the secured payment details have been successfully submitted to BlueSnap server.
     In a real app, you would send the checkout details to your app server, which then would call BlueSnap API
     to execute the purchase.
     In this sample app we do it client-to-server, but this is not the way to do it in a real app.
     Note that after a transaction was created with the token, you need to clear it or generate a new one for the next transaction.
     */

    private func completePurchase(sdkResult: BSBaseSdkResult!) {
        NSLog("BlueSnapSDKExample Completion func")
        self.waitingForPurchaseComplete = false;
        var result = [String:Any]();

        if (sdkResult.hasPriceDetails()) {
            result["priceDetails"] = [
                "amount":sdkResult.getAmount() as Any,
                "currency": sdkResult.getCurrency() as Any
            ];
        }

        result["fraudSessionId"] = sdkResult.getFraudSessionId();

        if let paypalResult = sdkResult as? BSPayPalSdkResult {

            result["method"] = "paypal";

            NSLog(
                "PayPal transaction completed Successfully! invoice ID \(paypalResult.payPalInvoiceId ?? "")");

            result["paypalInvoiceId"] = paypalResult.payPalInvoiceId ?? ""

            //return // no need to complete purchase via BlueSnap API
        } else if (sdkResult as? BSApplePaySdkResult) != nil {
            NSLog("Apple Pay details accepted")

            result["method"] = "applepay";

        } else if let ccResult = sdkResult as? BSCcSdkResult {
            let cc = ccResult.creditCard;

            NSLog("CC Expiration \(cc.getExpiration())");
            NSLog("CC type \(cc.ccType ?? "")");
            NSLog("CC last 4 digits \(cc.last4Digits ?? "")");
            NSLog("CC Issuing country \(cc.ccIssuingCountry ?? "")");

            result["method"] = "cc";
            result["cc"] = [
                "type": cc.ccType,
                "last4Digits": cc.last4Digits,
                "expirationDate": cc.getExpiration(),
            ];

            //If 3DS Authentication was successful, the result will be one of the following:
            //
            //AUTHENTICATION_SUCCEEDED = 3D Secure authentication was successful because the shopper entered their credentials correctly or the issuer authenticated the transaction without requiring shopper identity verification.
            //AUTHENTICATION_BYPASSED = 3D Secure authentication was bypassed due to the merchant's configuration.
            //If 3DS Authentication was not successful, the result will be one of the following errors:
            //
            //AUTHENTICATION_UNAVAILABLE = 3D Secure authentication is unavailable for this card.
            //AUTHENTICATION_FAILED = Card authentication failed in cardinal challenge.
            //THREE_DS_ERROR = Either a Cardinal internal error or a server error occurred.
            //CARD_NOT_SUPPORTED = No attempt to run 3D Secure challenge was done due to unsupported 3DS version.
            //AUTHENTICATION_CANCELED (only possible when using your own UI) = The shopper canceled the challenge or pressed the 'back' button in Cardinal activity.
            result["valid3DS"] = ccResult.threeDSAuthenticationResult;

            result["subscription"]  = sdkResult.isSubscriptionCharge()
        }
        (self.viewController as? UINavigationController)?.setNavigationBarHidden(true, animated: true);
        sendMessageToDart("checkoutResult", result as NSObject);
    }

    public func returningToFlutter() {
        let navigationController = self.viewController as? UINavigationController;
        if (!(self.oldDelegate is BluesnapNavigationDelegate)) {
            navigationController?.delegate = self.oldDelegate;
        }

        navigationController?.setNavigationBarHidden(true, animated: false);

        self.oldDelegate = nil;

        if (self.waitingForPurchaseComplete ?? false) {
            sendMessageToDart("checkoutFail", "userCanceled" as NSObject);
        }
    }

    var oldDelegate:UINavigationControllerDelegate?;
    var waitingForPurchaseComplete:Bool?;

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "setup":
            guard let args = call.arguments else {
                NSLog("Setup failed: no arguments defined");
                result("Setup failed: no arguments defined");
                return
            }

            self.viewController = UIApplication.shared.keyWindow!.rootViewController!;

            if let callArgs = args as? [String: Any],
                let token = callArgs["token"] as? String {

                let currency = callArgs["currency"] as? String;
                let appleId = callArgs["applePayMerchantIdentifier"] as? String;
                let disable3DS = callArgs["disable3DS"] as? Bool;

                do {
                    try self.token = BSToken(tokenStr: token);
                } catch {
                    NSLog("Token failed: \(error)")
                    result("Token fail: \(error)");
                    return;
                }

                self.currency = currency ?? "USD";
                self.applePayMerchantIdentifier = appleId ?? nil;
                self.disable3DS = disable3DS ?? false;

                do {
                    try self.sdkSetup();
                } catch {
                    NSLog("Setup failed: \(error)")
                    result("Setup fail: \(error)");
                    return;
                }

                result("Setup complete");
            } else {
                NSLog("Setup failed: token undefined");
                result("Setup failed: token undefined");
            }

            break;
        case "checkout":
            guard let args = call.arguments else {
                return
            }

            // Due to android not supporting predefined address details, support for iOS is not implemented
            if let callArgs = args as? [String: Any],
                let amount = callArgs["amount"] as? Double {

                let currency = callArgs["currency"] as? String;

                let priceDetails = BSPriceDetails(
                    amount: amount,
                    taxAmount: 0, // tax amount not support at this point of time
                    currency: currency ?? self.currency
                );
                let sdkRequest: BSSdkRequest! = BSSdkRequest(
                    withEmail: false,
                    withShipping: false,
                    fullBilling: false,
                    priceDetails: priceDetails,
                    billingDetails: nil, //BSBillingAddressDetails - not supported on android, so disabled..
                    shippingDetails: nil,  //BSShippingAddressDetails - not supported on android, so disabled..
                    purchaseFunc: self.completePurchase, // call after user has initiated purchase
                    updateTaxFunc: nil //optional for handling tax updates
                );

                sdkRequest.allowCurrencyChange = false;
                sdkRequest.hideStoreCardSwitch = callArgs["hideStoreCardSwitch"] as? Bool ?? false;
                sdkRequest.activate3DS = !self.disable3DS;

                let navigationController = self.viewController as? UINavigationController;
                self.oldDelegate = navigationController?.delegate;
                print("delegate type: \(String(describing: navigationController?.delegate))");
                navigationController?.delegate = self.navigationControllerDelegate;

                do {
                    try BlueSnapSDK.showCheckoutScreen(
                        inNavigationController: navigationController,
                        animated: true,
                        sdkRequest: sdkRequest)

                    self.waitingForPurchaseComplete = true;
                } catch {
                    NSLog("Unexpected error: \(error)");
                    sendMessageToDart("checkoutFail", "Unexpected error: \(error)" as NSObject);
                    result("Checkout failed: \(error)");
                }

            }

            //sdkRequest.priceDetails = BSPriceDetails(amount: 25.00, taxAmount: 1.52, currency: "USD")

            // var adddress : BSBaseAddressDetails! = BSBaseAddressDetails(
            //     name : String! = "",
            //     address : String? = ""
            //     city : String? = ""
            //     zip : String? = ""
            //     country : String? = ""
            //     state : String? = ""
            // )

            result("Checkout started");
            break;
        default:
            result("Unknown request")
            break;
        }
    }
}
