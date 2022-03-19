
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safebox/safebox.dart';
import 'dart:convert' as JSON;

void main() => runApp(KiwiApp());

class KiwiApp extends StatefulWidget{
    @override
    State<StatefulWidget> createState() {
      // TODO: implement createState
      return KiwiAppState();
    }

}

class KiwiAppState extends State<KiwiApp> {
  static const platformChannel =
  const MethodChannel('com.kiwi.native');

  @override
  void initState() {
    super.initState();
    platformChannel.setMethodCallHandler((methodCall) async {
      switch (methodCall.method) {
        case 'getMnemonic':
          return Safebox.generateWalletMnemonic();
        case 'getSafebox':
          String mnemonic = await methodCall.arguments['mnemonic'];
          print(mnemonic);
          if (mnemonic != null && mnemonic.isNotEmpty) {
            String json = Safebox.convertMnemonicToSafeBox(mnemonic);
            return json;
          } else {
            throw PlatformException(
                code: 'error', message: '失败', details: 'content is null');
          }
       case 'getSendTx':
          String jsonString = await methodCall.arguments['data'];
          return Safebox.getTranscation(jsonString);
        case 'getAddress':
          String pk = await methodCall.arguments['data'];
          return JSON.jsonEncode(Safebox.getAddress(pk));
        default:
          throw MissingPluginException();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Demo",
      home: Scaffold(
        appBar: AppBar(
          title: Text('Android调用Flutter'),
        ),
        body: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('Flutter端初始文字'),
        ),
      ),
    );
  }
}
