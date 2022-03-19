import 'dart:ffi';
import 'dart:typed_data';

import 'package:safebox/clvm/program.dart';
import 'package:safebox/core/ec.dart';
import 'package:safebox/core/fields.dart';
import 'package:safebox/util/util.dart';
import 'package:convert/convert.dart';
import 'package:safebox/wallet/private_key.dart';

class Puzzle {
  static Program get DEFAULTHIDDENPUZZLE =>
      Program.fromBytes(hex.decode('ff0980'));
  static List<int> get DEFAULTHIDDENPUZZLEHASH =>
      Program.sha256Treehash(DEFAULTHIDDENPUZZLE, null);

  static List<int> createPuzzlehashForPk(JacobianPoint publicKey) {
    return Program.sha256Treehash(puzzleForPk(publicKey), null);
  }

  static Program puzzleForPk(JacobianPoint publicKey) {
    return puzzleForPublicKeyAndHIddenPuzzleHash(
        publicKey, DEFAULTHIDDENPUZZLEHASH);
  }

  static PrivateKey calculateSyntheticSecretKey(
      PrivateKey secret_key, List<int> hidden_puzzle_hash) {
    var secret_exponent = BigInt.parse(secret_key.key, radix: 16);
    var public_key = secret_key.getPublicKeyPointWallet();
    var synthetic_offset =
        calculateSyntheticOffset(public_key, hidden_puzzle_hash);
    var synthetic_secret_exponent = (secret_exponent + synthetic_offset) % EC.n;
    return PrivateKey.fromBytes(Util.intToByte(synthetic_secret_exponent));
  }

  static BigInt calculateSyntheticOffset(
      JacobianPoint public_key, List<int> hidden_puzzle_hash) {
    var blob = Util.hash256(public_key.toBytes() + hidden_puzzle_hash);
    var offset = Util.toBigInt(blob, signed: true);
    offset %= EC.n;
    return offset;
  }

  static JacobianPoint caculateSyntheticPublicKey(
    JacobianPoint publicKey,
    List<int> hiddenPuzzleHash,
  ) {
    final sys = Program.SYNTHETICMOD;
    final r = sys.run([publicKey.toBytes(), hiddenPuzzleHash]);
    return JacobianPoint.fromBytes(r.atom!, Fq);
  }

  static Program puzzleForPublicKeyAndHIddenPuzzleHash(
    JacobianPoint publicKey,
    List<int> hiddenPuzzleHash,
  ) {
    final syntheticPubkeyKey =
        caculateSyntheticPublicKey(publicKey, hiddenPuzzleHash);
    return puzzleForSyntheticPublicKey(syntheticPubkeyKey);
  }

  static Program puzzleForSyntheticPublicKey(JacobianPoint syntheticPublicKey) {
    return Program.MOD.curry(syntheticPublicKey.toBytes());
  }

  static Program puzzleForConditions(List<dynamic> conditions) {
    return Program.MOD_SIGN.run([conditions]);
  }

  static solutionForDelegatedPuzzle({
    required Program delegatedPuzzle,
    required Program solution,
  }) {
    return Program.to([[], delegatedPuzzle, solution]);
  }

  static Program solutionFoConditions(List<dynamic> conditions) {
    var delegatedPuzzle = puzzleForConditions(conditions);
    return solutionForDelegatedPuzzle(
      delegatedPuzzle: delegatedPuzzle,
      solution: Program.to(0),
    );
  }

  static Program puzzleForPuzzleHash(JacobianPoint publicKey) {
    return puzzleForPk(publicKey);
  }

  // Future<JacobianPoint> hackPopulateSecretKeyForPuzzleHash(List<int> puzzleHash) {
  //   var
  // }

}
