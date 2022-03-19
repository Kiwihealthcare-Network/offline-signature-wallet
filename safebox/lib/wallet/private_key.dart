import 'dart:convert';
import 'dart:typed_data';

import 'package:safebox/clvm/puzzle.dart';
import 'package:safebox/core/bech32.dart';
import 'package:safebox/util/util.dart';
import 'package:crypto/crypto.dart';

import '../core/ec.dart';

class PrivateKey {
  final String key;
  PrivateKey({
    required this.key,
  });

  static const _blockSize = 32;
  static const _pathWalletKey = [12381, 8444, 2];

  factory PrivateKey.keyGen(List<int> seedBytes) {
    /// `ceil((3 * ceil(log2(r))) / 16)`, where `r` is the order of the BLS 12-381 curve
    const salt = 'BLS-SIG-KEYGEN-SALT-';
    const l = 48;
    final saltBytes = utf8.encode(salt);
    final keyBytes = seedBytes + [0];
    final infoBytes = [0] + Util.toBytes(l);
    final okm = _extractExpand(l, keyBytes, saltBytes, infoBytes);
    final okmBigInt = Util.toBigInt(okm);
    final key = (okmBigInt % EC.n).toRadixString(16);
    return PrivateKey(key: key);
  }

  factory PrivateKey.fromBytes(List<int> bytes) =>
      PrivateKey(key: Util.toHex(bytes));

  static List<int> _extractExpand(
    int l,
    List<int> key,
    List<int> salt,
    List<int> info,
  ) {
    final prk = _extract(salt, key);
    return _expand(l, prk, info);
  }

  static List<int> _extract(
    List<int> salt,
    List<int> ikm,
  ) {
    final prk = Hmac(sha256, salt).convert(ikm).bytes;
    return prk;
  }

  static List<int> _expand(
    int l,
    List<int> prk,
    List<int> info,
  ) {
    var tBytes = <int>[];
    var okm = <int>[];
    var bytesWritten = 0;
    var toWrite = 0;
    final int n = (l / _blockSize).ceil();
    for (var i = 1; i < n + 1; i++) {
      if (i == 1) {
        tBytes = Hmac(sha256, prk).convert(info + [01]).bytes;
      } else {
        final plus = i == 2 ? [02] : Util.toBytes(i);
        tBytes = Hmac(sha256, prk).convert(tBytes + info + plus).bytes;
      }
      toWrite = l - bytesWritten;
      if (toWrite > _blockSize) {
        toWrite = _blockSize;
      }
      okm += tBytes.sublist(0, toWrite);
      bytesWritten += toWrite;
    }
    return okm;
  }

  static List<int> _ikmToLamportSk(
    List<int> ikm,
    List<int> salt,
  ) {
    return _extractExpand(32 * 255, ikm, salt, []);
  }

  List<int> _parentSkToLamportPk(
    int index,
  ) {
    var salt = Util.toBytes(index);
    if (salt.length < 4) {
      salt = List<int>.filled(4 - salt.length, 0) + salt;
    }
    var ikm = Util.toBytes(this.key);
    var notIkm = ikm.map((e) => e ^ 255).toList();
    var lamport0 = _ikmToLamportSk(ikm, salt);
    var lamport1 = _ikmToLamportSk(notIkm, salt);
    var lamportPk = <int>[];
    for (var i = 0; i < 255; i++) {
      lamportPk += Util.hash256(lamport0.sublist(i * 32, (i + 1) * 32));
    }
    for (var i = 0; i < 255; i++) {
      lamportPk += Util.hash256(lamport1.sublist(i * 32, (i + 1) * 32));
    }
    return Util.hash256(lamportPk);
  }

  List<int> puzzleHash() {
    var pk = getPublicKeyPointWallet();
    return Puzzle.createPuzzlehashForPk(pk);
  }

  BigInt get keyValue => BigInt.parse(key, radix: 16);

  PrivateKey _deriveChildSk(int index) {
    /// """
    /// Derives a hardened EIP-2333 child private key, from a parent private key,
    /// at the specified index.
    /// """
    final lamportPk = _parentSkToLamportPk(index);
    return PrivateKey.keyGen(lamportPk);
  }

  PrivateKey _deriveChildSKUnhardened(int index) {
    var h = Util.hash256(
        getPublicKeyPointWallet().toBytes() + intToBytes(index, 4, Endian.big));
    var privateKeys = [Util.toBigInt(h), BigInt.parse(key, radix: 16)];
    var value = privateKeys.fold(BigInt.zero,
            (BigInt aggregate, privateKey) => aggregate + privateKey) %
        EC.n;
    return PrivateKey.fromBytes(Util.intToByte(value));
  }

  Uint8List intToBytes(int value, int size, Endian endian,
      {bool signed = false}) {
    if (value < 0 && !signed) {
      throw ArgumentError('Cannot convert negative int to unsigned.');
    }
    var binary =
        (value < 0 ? -value : value).toRadixString(2).padLeft(size * 8, '0');
    if (value < 0) {
      binary = (int.parse(flip(binary), radix: 2) + 1)
          .toRadixString(2)
          .padLeft(size * 8, '0');
    }
    var bytes = RegExp(r'[01]{8}')
        .allMatches(binary)
        .map((match) => int.parse(match.group(0)!, radix: 2))
        .toList();
    if (endian == Endian.little) {
      bytes = bytes.reversed.toList();
    }
    return Uint8List.fromList(bytes);
  }

  String flip(String binary) {
    return binary.replaceAllMapped(
        RegExp(r'[01]'), (match) => match.group(0) == '1' ? '0' : '1');
  }

  JacobianPoint getPublicKeyPointWallet() {
    final data = AffinePoint.g1().toJacobianPoin();
    return data * keyValue;
  }

  PrivateKey getChildPrivateKeyWallet(String derivationPath) {
    var index = int.parse(
        derivationPath.substring(derivationPath.lastIndexOf("/") + 1));
    final path = _pathWalletKey + [index];
    var sk = this.copyWith();
    for (var item in path) {
      sk = sk._deriveChildSk(item);
    }
    return sk;
  }

  PrivateKey getChildPK(List<int> keys) {
    final path = keys;
    var sk = this.copyWith();
    for (var item in path) {
      sk = sk._deriveChildSk(item);
    }
    return sk;
  }

  PrivateKey getChildPrivateKeyWalletUnhardened(String derivationPath) {
    var index = int.parse(
        derivationPath.substring(derivationPath.lastIndexOf("/") + 1));
    final path = _pathWalletKey + [index];
    var sk = this.copyWith();
    for (var item in path) {
      sk = sk._deriveChildSKUnhardened(item);
    }
    return sk;
  }

  String getAddressWallet() => Bech32m.encodePuzzleHash(puzzleHash());
  String getKiwiAddressWallet() => Bech32m.encodePuzzleHash(puzzleHash(),prefix:"tkik");

  PrivateKey copyWith({
    String? key,
  }) {
    return PrivateKey(
      key: key ?? this.key,
    );
  }

  @override
  String toString() => 'PrivateKey(key: $key)';
}
