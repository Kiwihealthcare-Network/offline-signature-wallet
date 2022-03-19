import 'package:safebox/core/ec.dart';
import 'package:crypto/crypto.dart';

class HashToField {
  static Iterable<List<BigInt?>?> hp2(
    List<int> msg,
    int count,
    List<int>? dst,
  ) {
    var result = hashToField(
        msg, count, dst, EC.q, 2, 64, expandMessageXmd, sha256.convert);
    return result;
  }

  static Iterable<List<BigInt?>?> hashToField(
    List<int> msg,
    int count,
    List<int>? dst,
    BigInt modulus,
    int degree,
    int blen,
    Function expandFn,
    Function hashFn,
  ) {
    ///# get pseudorandom bytes
    var lenInBytes = count * degree * blen;
    var pseudoRandomBytes = expandFn(msg, dst, lenInBytes, hashFn) as List<int>;
    var uVal = List<List<BigInt?>?>.filled(count, null);
    for (var idx in List.generate(count, (index) => index)) {
      var eVals = List<BigInt?>.filled(degree, null);
      for (var jdx in List.generate(degree, (index) => index)) {
        var elmOffset = blen * (jdx + idx * degree);
        var tv = pseudoRandomBytes.sublist(elmOffset, elmOffset + blen);
        eVals[jdx] = os2ip(tv) % modulus;
      }
      uVal[idx] = eVals;
    }
    return uVal;
  }

  static BigInt os2ip(List<int> octets) {
    var ret = BigInt.zero;
    for (var o in octets) {
      ret = ret << 8;
      ret += BigInt.from(o);
    }
    return ret;
  }

  ///defined in RFC 3447, section 4.1
  static List<int> i2osp(int val, int length) {
    if (val < 0 || BigInt.from(val) >= (BigInt.one << (8 * length))) {
      throw Exception('Error, bad I2OSP call');
    }
    var ret = List<int>.filled(length, 0);
    var _val = val;
    for (var idx in List.generate(length, (index) => length - index - 1)) {
      ret[idx] = _val & 255;
      _val = _val >> 8;
    }
    return ret;
  }

  static List<int> expandMessageXmd(
    List<int> msg,
    List<int> dst,
    int lenInBytes,
    Function hashFn,
  ) {
//  input and output lengths for hash_fn
    //sha256
    var bInBytes = 32;
    var rInBytes = 64;
// ell, dst_printtme, etc
    var ell = (lenInBytes + bInBytes - 1) ~/ bInBytes;
    if (ell > 255) {
      throw Exception('Error, expand_message_xmd');
    }
    var dstPrime = dst + i2osp(dst.length, 1);
    var zPad = i2osp(0, rInBytes);
    var libStr = i2osp(lenInBytes, 2);
    var b0 = sha256.convert(zPad + msg + libStr + i2osp(0, 1) + dstPrime).bytes;
    var bVals = List<List<int>?>.filled(ell, null);
    bVals[0] = sha256.convert(b0 + i2osp(1, 1) + dstPrime).bytes;
    for (var idx in List.generate(ell - 1, (index) => index + 1)) {
      bVals[idx] = sha256
          .convert(_strXor(b0, bVals[idx - 1]!) + i2osp(idx + 1, 1) + dstPrime)
          .bytes;
    }
    var pseudoRandomBytes = <int>[];
    for (var _ in bVals) {
      pseudoRandomBytes += _!;
    }
    return pseudoRandomBytes.sublist(0, lenInBytes);
  }

  static List<int> _strXor(List<int> str1, List<int> str2) {
    var result = <int>[];
    for (var _ in _zip(str1, str2)) {
      result.add(_[0] ^ _[1]);
    }
    return result;
  }

  static List<List<int>> _zip(List<int> str1, List<int> str2) {
    var result = <List<int>>[];
    for (var i = 0; i < str1.length; i++) {
      if (i >= str2.length) {
        return result;
      }
      result.add([str1[i], str2[i]]);
    }
    return result;
  }
}
