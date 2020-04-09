import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class FlutterBluesnap {
  static final FlutterBluesnap _instance = FlutterBluesnap._internal();

  factory FlutterBluesnap() {
    return _instance;
  }

  FlutterBluesnap._internal();

  static const MethodChannel _channel = const MethodChannel('flutter_bluesnap');

  static const String BS_VAULTED_SHOPPER = "vaulted-shoppers";
  static const String BS_PLAN = "recurring/plans";
  static const String BS_SUBSCRIPTION = "recurring/subscriptions";

  static Completer _setupRequest, _checkoutRequest;

  static bool _initialized = false;

  static Function _requestTokenHandler;

  static get tokenRequestHandler => _requestTokenHandler;
  static set tokenRequestHandler(Function handler) {
    if (_requestTokenHandler == null) {
      _requestTokenHandler = handler;
    } else {
      throw UnsupportedError("Token handler has already been set");
    }
  }

  // Example for receiving method invocations from platform and return results.
  static _listen() {
    if (!_initialized) {
      FlutterBluesnap();
      _channel.setMethodCallHandler((MethodCall call) async {
        print('Got message: $call');
        switch (call.method) {
          case 'getNewToken':
            print('Request new token');
            if (tokenRequestHandler != null) {
              String token = await _requestTokenHandler(call.arguments);
              return token;
            }
            break;
          case 'setupComplete':
            print('Setup completed succesfully: ${call.arguments}');
            if (_setupRequest != null) {
              print('resolve completer');
              _setupRequest.complete(call.arguments);
              _setupRequest = null;
            } else {
              print('Setup request is null?!');
            }
            break;
          case 'setupFailed':
            print('Setup failed: ${call.arguments}');
            if (_setupRequest != null) {
              Exception fail = Exception(call.arguments);
              _setupRequest.completeError(fail);
              _setupRequest = null;
            }
            break;
          case 'checkoutResult':
            print('Checkout succesfully: ${call.arguments}');
            if (_checkoutRequest != null) {
              _checkoutRequest.complete(call.arguments);
            }
            break;
          case 'requestFail':
          case 'checkoutFail':
            print('There was a request error: ${call.arguments}');
            if (_checkoutRequest != null) {
              print("Sending fail to checkout request");
              Exception fail = Exception(call.arguments);
              _checkoutRequest.completeError(fail);
              _checkoutRequest = null;
            } else {
              print('Checkout request is null?!');
            }
            break;
          default:
            throw MissingPluginException();
        }
        return null;
      });
      _initialized = true;
    }
  }

  static String _currency;
  static bool _enableGooglePay = false;
  static bool _enablePaypal = false;
  static bool _enableApplePay = false;
  static bool _enableProduction = false;
  static bool _disable3DS = false;

  static Future<dynamic> setup(
      {String token,
      String currency,
      bool enableGooglePay,
      bool enablePaypal,
      bool enableApplePay,
      bool enableProduction,
      bool disable3DS}) async {
    _listen();

    enableGooglePay = enableGooglePay ?? _enableGooglePay;
    enablePaypal = enablePaypal ?? _enableApplePay;
    enableApplePay = enableApplePay ?? _enablePaypal;
    enableProduction = enableProduction ?? _enableProduction;
    disable3DS = disable3DS ?? _disable3DS;
    currency = currency ?? _currency;

    _enableGooglePay = enableGooglePay;
    _enablePaypal = enablePaypal;
    _enableApplePay = enableApplePay;
    _enableProduction = enableProduction;
    _disable3DS = disable3DS;
    _currency = currency;

    _setupRequest = Completer();

    print('Start setup with: $token');

    await _channel.invokeMethod('setup', {
      "token": token,
      "currency": currency,
      "enableGooglePay": enableApplePay,
      "enableApplePay": enableApplePay,
      "enableProduction": enableProduction,
      "disable3DS": disable3DS
    });

    return _setupRequest.future;
  }

  static Future<dynamic> checkout(
      {double amount, String currency, String token}) async {
    if (!_initialized) {
      throw StateError("Bluesnap not intialized, run setup first.");
    }

    if (token != null) {
      try {
        await setup(token: token);
      } catch (e) {
        print("Bluesnap setup failed $e");
        throw Exception("Bluesnap setup failed $e");
      }
    }

    _checkoutRequest = Completer();

    print('Start checkout for: $amount');

    await _channel
        .invokeMethod('checkout', {"amount": amount, "currency": currency});

    return _checkoutRequest.future;
  }

  static Future<String> generateDummyToken(
      {bsSandboxUser,
      bsSandboxPw,
      domain: 'https://sandbox.bluesnap.com/services/2/',
      shopperId}) async {
    Uri url;

    if (shopperId == null) {
      url = Uri.parse("${domain}payment-fields-tokens");
    } else {
      url = Uri.parse("${domain}payment-fields-tokens?shopperId=$shopperId");
    }

    HttpClient client = new HttpClient();

    client.addCredentials(url, 'realm',
        new HttpClientBasicCredentials(bsSandboxUser, bsSandboxPw));

    String token;

    await client.postUrl(url).then((HttpClientRequest req) {
      req.headers
        ..add(HttpHeaders.acceptHeader, 'application/json')
        ..add(HttpHeaders.contentTypeHeader, 'application/json');

      print(
          "\n\nRequest $url $bsSandboxUser $bsSandboxPw ${req.headers.toString()} ${req.toString()}");

      return req.close();
    }).then((HttpClientResponse res) {
      int statusCode = res.statusCode;
      client.close();

      String location = res.headers.value(HttpHeaders.locationHeader);
      print("\n\nResponse $res ${res.headers}");
      print("$statusCode - Location: $location");
      if (location != null) {
        token = location.split('/').last;
      } else {
        throw HttpException(statusCode.toString());
      }
    });

    return token;
  }
}
