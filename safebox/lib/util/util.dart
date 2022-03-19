import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

class Util {
  static String toHex(dynamic num) {
    if (num is int || num is BigInt) {
      final result = num.toRadixString(16);
      return result.length % 2 == 1 ? '0' + result : result;
    } else if (num is List<int>) {
      final result = hex.encode(num);
      return result.length % 2 == 1 ? '0' + result : result;
    } else {
      throw Exception('Error, num must be int or BigInt');
    }
  }

  static List<int> toBytes(dynamic num, {int? length}) {
    var data = <int>[];
    if (num is int || num is BigInt) {
      final result = toHex(num);
      data = hex.decode(result);
    } else if (num is String) {
      if (num.length % 2 == 1) {
        num = '0' + num;
      }
      data = hex.decode(num);
    } else {
      throw Exception('Error, num must be int or BigInt or String hex');
    }
    if (length != null) {
      if (data.length < length) {
        return List.filled(length - data.length, 0) + data;
      }
    }
    return data;
  }

  static int toInt(List<int> bytes, {bool signed = false}) {
    if (bytes.isEmpty) {
      return 0;
    }
    final result = toHex(bytes);
    if (signed) {
      var data = int.parse(result, radix: 16);
      return data.toSigned(64);
    }
    return int.parse(result, radix: 16);
  }

  static BigInt toBigInt(List<int> bytes, {bool signed = false}) {
    if (bytes.isEmpty) {
      return BigInt.zero;
    }
    final result = toHex(bytes);
    if (signed) {
      var data = BigInt.parse(result, radix: 16);
      return data.toSigned(256);
    }
    return BigInt.parse(result, radix: 16);
  }

  static List<int> hash256(List<int> m) {
    return sha256.convert(m).bytes;
  }

  static int msbMask(int byte) {
    byte |= byte >> 1;
    byte |= byte >> 2;
    byte |= byte >> 4;
    return (byte + 1) >> 1;
  }

  static bool compareBytes(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    final value1 = toHex(a);
    final value2 = toHex(b);
    return value1 == value2;
  }

  static BigInt limbsForBigInt(BigInt v) {
    ///"""
    ///Return the number of bytes required to represent this integer.
    ///"""
    return BigInt.from((v.bitLength + 7) >> 3);
  }

  static List<int> intToByte(dynamic v) {
    var byteCount = (v.bitLength + 8) >> 3;
    if (v == 0) {
      return [];
    }
    var r = toBytes(v, length: byteCount);
    while (r.length > 1 && r[0] == (r[1] & 128 != 0 ? 255 : 0)) {
      r = r.sublist(1);
    }
    return r;
  }

  static List<int> stdHash(List<int> data) {
    return sha256.convert(data).bytes;
  }

  // List<List<E>> _zip(Iterable<E> str1, Iterable<E> str2) {
  //   var result = <List<E>>[];
  //   for (var i = 0; i < str1.length; i++) {
  //     if (i >= str2.length) {
  //       return result;
  //     }
  //     result.add([str1.elementAt(i), str2.elementAt(i)]);
  //   }
  //   return result;
  // }
}

extension Compare on List {
  bool operator >(List other) {
    if (other.isEmpty && this.isEmpty) {
      return false;
    }
    if (this.isNotEmpty && other.isEmpty) {
      return true;
    }
    if (this.isEmpty && other.isNotEmpty) {
      return false;
    }
    for (var i = 0; i < this.length; i++) {
      if (this[i] > other[i]) {
        return true;
      } else if (this[i] < other[i]) {
        return false;
      } else {
        if (i == this.length - 1) {
          return false;
        }
        if (i == other.length - 1) {
          return true;
        }
      }
    }
    return true;
  }
}
