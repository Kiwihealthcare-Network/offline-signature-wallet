import 'dart:convert' as JSON;

import 'package:bip39/bip39.dart';
import 'package:safebox/util/util.dart';
import 'package:safebox/wallet/chia_wallet.dart';
import 'package:safebox/wallet/private_key.dart';
import 'package:safebox/wallet/transaction.dart';

class Safebox{

  static String generateWalletMnemonic() {
    String mnemonic = generateMnemonic(strength: 256);
    return mnemonic;
  }

  static String convertMnemonicToSafeBox(String mnemonic) {
    var seed = mnemonicToSeed(mnemonic);
    var sk = PrivateKey.keyGen(seed);
    var pk = sk.getPublicKeyPointWallet();
    var fingerprint = pk.getFingerprint();

    final addressSK = sk.getChildPrivateKeyWalletUnhardened("12381'/8444'/2'/0");
    final chiaAddress = addressSK.getAddressWallet();
    final address =  addressSK.getKiwiAddressWallet();

    //12381/8444/0/0
    final farmerSK = sk.getChildPK([12381,8444,0,0]);
    //12381/8444/1/0
    final poolSK = sk.getChildPK([12381,8444,1,0]);
    //12381/8444/3/0
    final secrtSK = sk.getChildPK([12381,8444,3,0]);
    var map = new Map();
    map["privateKey"]= Util.toHex(sk.keyValue);
    map["publicKey"]= Util.toHex(pk.toBytes());
    map["farmer"]= Util.toHex(farmerSK.getPublicKeyPointWallet().toBytes());
    map["pool"] = Util.toHex(poolSK.getPublicKeyPointWallet().toBytes());
    map["secrt"] = Util.toHex(secrtSK.keyValue);
    map["fingerprint"]= fingerprint;
    // map["puzzleHash"]= Util.toHex(addressSK.puzzleHash());
    // map["chiaPuzzleHash"]= Util.toHex(addressSK.puzzleHash());
    map["firstKIWIAddress"]= address;
    map["fisrtChiaAddress"]= chiaAddress;
    map["address"] = getAddress(sk.key);
    // map["walletSk"] = addressSK.key;
    return JSON.jsonEncode(map);
  }

  static String getTranscation(String jsonString) {
    var jsonObj = JSON.jsonDecode(jsonString);
    var toAddress = jsonObj["toAddress"];
    var marstSk = PrivateKey(key: jsonObj["privateKey"]);
    List array = jsonObj["data"];
    List<SpendBundle> result = [];
    for (var json in array) {
      List utxosArray = json["utxos"];
      List<CoinUnspent> utxos = [];
      for (var value in utxosArray) {
        utxos.add(CoinUnspent.fromJson(value));
      }
      var hand = json["hardened"];
      var addressSK;
      if(hand == 0){
        addressSK = marstSk.getChildPrivateKeyWallet("12381'/8444'/2'/"+json["index"].toString());
      }else{
        addressSK = marstSk.getChildPrivateKeyWalletUnhardened("12381'/8444'/2'/"+json["index"].toString());
      }
      result.add(ChiaWallet.signTransaction(
          amount: BigInt.parse(json["amount"],radix: 10),
          from: json["address"],
          to: toAddress,
          fee: BigInt.from(0),
          privateKey:addressSK.key,
          utxos: utxos));
    }
    return JSON.jsonEncode(result);
  }

  static Map getAddress(String pk){
    var marstSk = PrivateKey(key: pk);
    var chiaList = <String>[];
    var chiahardened = <String>[];
    var tkiklist = <String>[];
    var tkikhardened = <String>[];

    for(var i=0;i<10;i++){
      var addressSK = marstSk.getChildPrivateKeyWallet("12381'/8444'/2'/"+i.toString());
      var hAddressSK = marstSk.getChildPrivateKeyWalletUnhardened("12381'/8444'/2'/"+i.toString());

      chiaList.add(addressSK.getAddressWallet());
      chiahardened.add(hAddressSK.getAddressWallet());

      tkiklist.add(addressSK.getKiwiAddressWallet());
      tkikhardened.add(hAddressSK.getKiwiAddressWallet());
    }
    var chiaAddress = new Map();
    chiaAddress["address"] = chiaList;
    chiaAddress["hardened"] = chiahardened;
    var tkikAddress = new Map();
    tkikAddress["address"] = tkiklist;
    tkikAddress["hardened"] = tkikhardened;


    var map = new Map();
    map["chiaAddress"] = chiaAddress;
    map["kiwiAddress"] = tkikAddress;
    return map;

  }

}