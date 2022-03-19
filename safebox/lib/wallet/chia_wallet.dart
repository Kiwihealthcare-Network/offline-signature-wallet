import 'package:bip39/bip39.dart' as bip39;
import 'package:safebox/clvm/puzzle.dart';
import 'package:safebox/core/bech32.dart';
import 'package:safebox/core/ec.dart';
import 'package:safebox/util/util.dart';
import 'package:safebox/wallet/private_key.dart';
import 'package:safebox/wallet/transaction.dart';

class ChiaWallet {
  static final ChiaWallet _chiaWallet = ChiaWallet._internal();

  factory ChiaWallet() => _chiaWallet;

  ChiaWallet._internal();

  late final String _mnemonic;

  void init(String mnemonic) => _mnemonic = mnemonic;

  String get _seedHex => bip39.mnemonicToSeedHex(_mnemonic);

  List<int> get _seedBytes => Util.toBytes(_seedHex);

  PrivateKey get _masterKey => PrivateKey.keyGen(_seedBytes);

  JacobianPoint get _publicMasterKey => _masterKey.getPublicKeyPointWallet();

  String get masterKey => _masterKey.key;

  String get publicMasterKey => _publicMasterKey.toHex();

  static List<String> getAddressFromSeed(String mnemonic) {
    final seedHex = bip39.mnemonicToSeedHex(mnemonic);
    final seedBytes = Util.toBytes(seedHex);
    final masterKey = PrivateKey.keyGen(seedBytes);
    final address = masterKey
        .getChildPrivateKeyWallet("m/12381'/8444'/2'/0")
        .getAddressWallet();
    final privateKey =
        masterKey.getChildPrivateKeyWallet("m/12381'/8444'/2'/0").key;
    return [address, privateKey];
  }

  static String addressFromPrivateKey(String privateKey) =>
      PrivateKey(key: privateKey).getAddressWallet();

  String getWalletKey(String derivationPath) =>
      _masterKey.getChildPrivateKeyWallet(derivationPath).key;

  String getAddress(String derivationPath) =>
      _masterKey.getChildPrivateKeyWallet(derivationPath).getAddressWallet();

  static SpendBundle signTransaction({
    required BigInt amount,
    required String from,
    required String to,
    required BigInt fee,
    required String privateKey,
    required List<CoinUnspent> utxos,
  }) {
    var secret_key = PrivateKey(key: privateKey);
    // secret_key = Puzzle.calculateSyntheticSecretKey(
    //     secret_key, Puzzle.DEFAULTHIDDENPUZZLEHASH);
    return Transaction.generateSignedTransaction(
      amount: amount,
      from: from,
      to: to,
      fee: fee,
      privateKey: secret_key,
      utxos: utxos,
    );
  }

  static String getPuzzleHashFromAddress(String address) =>
      Util.toHex(Bech32m.decodePuzzleHash(address));

  static String getAddressFromPuzzleHash(String puzzleHash) =>
      Bech32m.encodePuzzleHash(Util.toBytes(puzzleHash));

  static bool checkValidAddress(String address) {
    try {
      Bech32m.decodePuzzleHash(address);
      return true;
    } catch (exp) {
      return false;
    }
  }
}
