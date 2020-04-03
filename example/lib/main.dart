import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bluesnap/flutter_bluesnap.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _statusMessage = 'Unknown';
  bool _initialized = false;
  double amount = 15;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String dummyToken, statusMessage = 'processing...';
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      dummyToken = await FlutterBluesnap.generateDummyToken(
          bsSandboxUser: '[SandboxUserName]', bsSandboxPw: '[SandboxPassword]');

      await FlutterBluesnap.setup(token: dummyToken, disable3DS: true);
      statusMessage = 'Setup complete.';
      _initialized = true;

      print('setup successful');
    } on PlatformException {
      dummyToken = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _statusMessage = statusMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
            margin: EdgeInsets.all(20),
            child: Column(children: [
              Text('State: $_statusMessage\n'),
              TextFormField(
                decoration: InputDecoration(labelText: 'Amount'),
                initialValue: amount.toString(),
                onChanged: (val) => setState(() => amount = double.parse(val)),
              ),
              Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: RaisedButton(
                      onPressed: _initialized
                          ? () {
                              print('Checkout $amount');
                              FlutterBluesnap.checkout(amount: amount);
                            }
                          : null,
                      child: Text('Checkout'))),
            ])),
      ),
    );
  }
}
