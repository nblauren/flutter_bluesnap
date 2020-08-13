package com.blidz.bluesnap.flutter_bluesnap;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.bluesnap.androidapi.models.ChosenPaymentMethod;
import com.bluesnap.androidapi.models.SdkRequest;
import com.bluesnap.androidapi.models.SdkResult;
import com.bluesnap.androidapi.services.BSPaymentRequestException;
import com.bluesnap.androidapi.services.BlueSnapService;
import com.bluesnap.androidapi.services.BluesnapServiceCallback;
import com.bluesnap.androidapi.services.TokenProvider;
import com.bluesnap.androidapi.services.TokenServiceCallback;
import com.bluesnap.androidapi.views.activities.BluesnapCheckoutActivity;
import com.bluesnap.androidapi.views.activities.BluesnapChoosePaymentMethodActivity;

import java.util.HashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * FlutterBluesnapPlugin
 */
public class FlutterBluesnapPlugin
        implements FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {

    private static final String TAG = "FlutterBluesnapPlugin";
    private static final String channelName = "flutter_bluesnap";
    private static final int BS_CHECKOUT_REQUEST = 811021;
    private static final int BS_PAYMENT_REQUEST = 811022;
    private static final int BS_OTHER_REQUEST = 811023;

    // protected FlutterPluginBinding binding;
    protected BlueSnapService bluesnapService;
    protected TokenProvider tokenProvider;
    protected MethodChannel methodChannel;
    protected String token, currency;
    protected Boolean enableGooglePay, enablePaypal, enableProduction, disable3DS;
    protected Context applicationContext;
    protected Activity activity;

    public FlutterBluesnapPlugin() {
        bluesnapService = BlueSnapService.getInstance();
        setupTokenProvider();
    }

    private FlutterBluesnapPlugin(Context applicationContext, MethodChannel methodChannel, Activity activity) {
        bluesnapService = BlueSnapService.getInstance();
        setupTokenProvider();
        this.applicationContext = applicationContext;
        this.methodChannel = methodChannel;
        this.activity = activity;
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        Log.i(TAG, "Attach bluesnap plugin to engine");

        applicationContext = binding.getApplicationContext();
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), channelName);
        methodChannel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
    }

    private void sendMessageToDart(String method) {
        sendMessageToDart(method, null);
    }

    private void sendMessageToDart(final String method, @Nullable final Object value) {
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                // Call the desired channel message here.
                methodChannel.invokeMethod(method, value, new MethodChannel.Result() {
                    @Override
                    public void success(@Nullable Object result) {
                        Log.i(TAG, "Message sent successfully");
                    }

                    @Override
                    public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                        Log.e(TAG, "Method call failed: " + errorMessage);
                    }

                    @Override
                    public void notImplemented() {
                        Log.e(TAG, "Method not implemented in dart");
                    }
                });
            }
        });
    }

    private void setupTokenProvider() {
        tokenProvider = new TokenProvider() {
            @Override
            public void getNewToken(final TokenServiceCallback tokenServiceCallback) {
                requestNewTokenFromDart(new TokenServiceInterface() {
                    @Override
                    public void onServiceSuccess() {
                        // change the expired token
                        tokenServiceCallback.complete(token);
                    }

                    @Override
                    public void onServiceFailure() {
                        // TODO: Error handling?
                    }
                });
            }
        };
    }

    private void requestNewTokenFromDart(final TokenServiceInterface tokenServiceInterface) {
        methodChannel.invokeMethod("getNewToken", null, new MethodChannel.Result() {
            @Override
            public void success(@Nullable Object result) {
                Log.i(TAG, "Got new token: " + result);
                token = result.toString();
                tokenServiceInterface.onServiceSuccess();
            }

            @Override
            public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                Log.e(TAG, "Method call failed: " + errorMessage);
            }

            @Override
            public void notImplemented() {
                Log.e(TAG, "Method not implemented in dart");
            }
        });
    }

    private void sdkSetup() {
        bluesnapService.setup(token, tokenProvider, currency, applicationContext, new BluesnapServiceCallback() {
            @Override
            public void onSuccess() {
                sendMessageToDart("setupComplete", null);
            }

            @Override
            public void onFailure() {
                // Bluesnap does not provide details...
                sendMessageToDart("setupFailed", "Issue with Bluesnap setup");
            }
        });
    }

    protected void completePurchase(final SdkResult sdkResult) {
        Log.d(TAG, "Format complete purchase result: " + sdkResult.toString());
        HashMap<String, Object> result = new HashMap<>();

        result.put("fraudSessionId", sdkResult.getKountSessionId());

        if (sdkResult.getAmount() != null) {
            HashMap<String, Object> priceDetails = new HashMap<>();

            priceDetails.put("amount", sdkResult.getAmount());
            priceDetails.put("currency", sdkResult.getCurrencyNameCode());

            result.put("priceDetails", priceDetails);
        }

        switch (sdkResult.getChosenPaymentMethodType()) {
            case ChosenPaymentMethod.PAYPAL:
                result.put("method", "paypal");
                result.put("paypalInvoiceId", sdkResult.getPaypalInvoiceId());
                break;
            case ChosenPaymentMethod.GOOGLE_PAY:
                result.put("method", "googlepay");
                result.put("googlePayToken", sdkResult.getGooglePayToken());

                break;
            case ChosenPaymentMethod.CC:
                result.put("method", "cc");

                HashMap<String, Object> cc = new HashMap<>();

                cc.put("type", sdkResult.getCardType());
                cc.put("last4Digits", sdkResult.getLast4Digits());
                cc.put("expirationDate", sdkResult.getExpDate());

                result.put("cc", cc);
                result.put("valid3DS", sdkResult.getThreeDSAuthenticationResult());

                break;
        }

        sendMessageToDart("checkoutResult", result);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        // Setup requires merchantId, tokenId, currency to be set.
        switch (call.method) {
            case "setup":
                token = call.argument("token");
                currency = call.argument("currency");
                currency = currency != null ? currency : "USD";
                enableGooglePay = call.argument("enableGooglePay");
                enablePaypal = call.argument("enablePaypal");
                enableProduction = call.argument("enableProduction");
                disable3DS = call.argument("disable3DS");

                sdkSetup();
                result.success("Setup complete");
                break;
            case "checkout":

                Double amount = call.argument("amount");
                String requestCurrency = call.argument("currency");
                Boolean hideStoreCardSwitch = call.argument("hideStoreCardSwitch");

                requestCurrency = (requestCurrency != null) ? (requestCurrency) : currency;

                SdkRequest sdkRequest = new SdkRequest(amount, requestCurrency, false, false, false);

                if (enableGooglePay) {
                    sdkRequest.setGooglePayActive(false);
                    // TODO: Detect production
                }
                if (enableProduction) {
                    sdkRequest.setGooglePayTestMode(false);
                }

                sdkRequest.setActivate3DS(!disable3DS);
                sdkRequest.setHideStoreCardSwitch(hideStoreCardSwitch != null ? hideStoreCardSwitch : false);

                // allowCurrencyChange property: if true, the SDK will allow the shopper to
                // change the purchase currency. By default it is true; if you wish to prevent
                // your shoppers from changing the currency, you can specifically change this
                // value like this:
                // sdkRequest.setAllowCurrencyChange(false);

                // setGooglePayActive method: if you support Google Pay as a payment method (in
                // BlueSnap console), it will be enabled for the shopper inside the SDK (in case
                // the device supports it). If you wish to disable Google Pay for this purchase,
                // you can do it like this:
                // sdkRequest.setGooglePayActive(false);

                // googlePayTestMode property: if true (default), Google Pay flow will work in
                // TEST mode, which means any card you enter will result in dummy card details.
                // If you set it to false, the SDK will instatiate Google Pay in PRODUCTION
                // mode, which requires Google's approval of the app. If your app is not
                // approved and you set to PRODUCTION mode, when clicking on the Google Pay
                // button, you will get a pop-up saying "This merchant is not enabled for Google
                // Pay"). Google Pay TEST mode is only supported in BlueSnap's Sandbox
                // environment; if you try it in production, the app flow will work, but your
                // transaction will fail. You can specifically change this value like this:
                // sdkRequest.setGooglePayTestMode(false);

                // hideStoreCardSwitch property: if true, the SDK will hide the "Securely store
                // my card" switch from the shopper and the card will not be stored in BlueSnap
                // server. By default it is false; if you wish to hide the store card switch,
                // you can specifically change this value like this:
                // sdkRequest.setHideStoreCardSwitch(true);

                // activate3DS property: if true, the SDK will require a 3D Secure
                // Authentication from the shopper when paying with credit card. By default it
                // is false; if you wish to activate 3DS Authentication, you can specifically
                // change this value like this:
                // sdkRequest.setActivate3DS(true);

                try {
                    bluesnapService.setSdkRequest(sdkRequest);
                } catch (BSPaymentRequestException e) {
                    e.printStackTrace();
                    result.error("Checkout failed", null, null);
                    return;
                }

                Intent intent = new Intent(applicationContext, BluesnapCheckoutActivity.class);
                activity.startActivityForResult(intent, BS_CHECKOUT_REQUEST);

                result.success("Checkout started");

                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        // Log.d(TAG, "Activity result: " + requestCode + " " + resultCode);

        if (requestCode == BS_CHECKOUT_REQUEST || requestCode == BS_PAYMENT_REQUEST) {

            if (resultCode != BluesnapCheckoutActivity.RESULT_OK) {
                if (data != null) {
                    String sdkErrorMsg = "SDK Failed to process the request: ";
                    sdkErrorMsg += data.getStringExtra(BluesnapCheckoutActivity.SDK_ERROR_MSG);
                    sendMessageToDart("requestFail", sdkErrorMsg);
                } else {
                    sendMessageToDart("checkoutFail", "userCanceled");
                }
                return false;
            }

            // Bundle extras = data.getExtras();
            SdkResult sdkResult = data.getParcelableExtra(BluesnapCheckoutActivity.EXTRA_PAYMENT_RESULT);

            // if (BluesnapCheckoutActivity.BS_CHECKOUT_RESULT_OK == sdkResult.getResult())
            // {
            // ?!?: && resultCode ==
            // BluesnapChoosePaymentMethodActivity.BS_CHOOSE_PAYMENT_METHOD_RESULT_OK

            // this result will be returned from both BluesnapCheckoutActivity and
            // BluesnapCreatePaymentActivity,
            // since handling is the same. BluesnapChoosePaymentMethodActivity has a
            // different OK result code.
            if (BluesnapCheckoutActivity.BS_CHECKOUT_RESULT_OK == sdkResult.getResult()) {
                completePurchase(sdkResult);

                // Call app server to process the payment
            } else {
                // TODO failed payment?
                Log.e(TAG, "Payment failed? " + sdkResult.getResult());
            }
            // }

        }

        return false;
    }

    // This static function is optional and equivalent to onAttachedToEngine. It
    // supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new
    // Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    //
    // It is encouraged to share logic between onAttachedToEngine and registerWith
    // to keep
    // them functionally equivalent. Only one of onAttachedToEngine or registerWith
    // will be called
    // depending on the user's project. onAttachedToEngine or registerWith must both
    // be defined
    // in the same class.
    public static void registerWith(Registrar registrar) {
        Log.i(TAG, "Attach bluesnap plugin to engine via registerWith");
        final MethodChannel methodChannel = new MethodChannel(registrar.messenger(), channelName);
        methodChannel.setMethodCallHandler(
                new FlutterBluesnapPlugin(registrar.context(), methodChannel, registrar.activity()));
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {

    }

    @Override
    public void onDetachedFromActivity() {

    }

}