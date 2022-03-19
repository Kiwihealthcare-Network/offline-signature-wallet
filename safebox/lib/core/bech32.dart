import 'package:safebox/clvm/sexp.dart';

const M = 734539939;
const CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

class Bech32m {
  static String encodePuzzleHash(List<int> puzzleHash,
      {String prefix = 'xch'}) {
    var encoded = bech32Encode(prefix, convertbits(puzzleHash, 8, 5));
    return encoded;
  }

  static String bech32Encode(String hrp, List<int> data) {
    ///"""Compute a Bech32 string given HRP and data values."""
    var combined = data + bech32CreateChecksum(hrp, data);
    var result = combined.map((e) => CHARSET[e]).join();
    return hrp + "1" + result;
  }

  static Iterable<dynamic> bech32Decode(String bech) {
    /// """Validate a Bech32 string, and determine HRP and data."""
    var bechNew = bech.toLowerCase();
    if (bech.codeUnits.every((element) => element < 33 || element > 126)) {
      return Tupple.iterable2(null, null);
    }
    if (bechNew != bech && bech.toUpperCase() != bech) {
      return Tupple.iterable2(null, null);
    }
    var pos = bechNew.lastIndexOf('1');
    if (pos < 1 || pos + 7 > bechNew.length || bechNew.length > 90) {
      return Tupple.iterable2(null, null);
    }

    var hrp = bechNew.substring(0, pos);
    var data = <int>[];
    for (var i = pos + 1; i < bechNew.length; i++) {
      final index = CHARSET.indexOf(bechNew[i]);
      if (index != -1) {
        data.add(index);
      } else {
        return Tupple.iterable2(null, null);
      }
    }
    if (!bech32VerifyCheckSum(hrp, data)) {
      return Tupple.iterable2(null, null);
    }
    return Tupple.iterable2(hrp, data.sublist(0, data.length - 6));
  }

  static bool bech32VerifyCheckSum(
    String hrp,
    List<int> data,
  ) {
    return bech32Polymod(bech32HrpExpand(hrp) + data) == M;
  }

  static List<int> convertbits(List<int> data, int fromBits, int toBits,
      {bool pad = true}) {
    /// """General power-of-2 base conversion."""
    var acc = 0;
    var bits = 0;
    var ret = <int>[];
    var maxv = (1 << toBits) - 1;
    var maxAcc = (1 << (fromBits + toBits - 1)) - 1;
    for (var value in data) {
      if (value < 0 || ((value >> fromBits) != 0)) {
        throw Exception('Error, Invalid value');
      }
      acc = ((acc << fromBits) | value) & maxAcc;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        ret.add((acc >> bits) & maxv);
      }
    }
    if (pad) {
      if (bits != 0) {
        ret.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv != 0)) {
      throw Exception('Error, Invalid bits');
    }
    return ret;
  }

  static List<int> bech32CreateChecksum(String hrp, List<int> data) {
    var values = bech32HrpExpand(hrp) + data;
    var polymod = bech32Polymod(values + List.filled(6, 0)) ^ M;
    var result = Iterable<int>.generate(6)
        .map((e) => (polymod >> 5 * (5 - e)) & 31)
        .toList();
    return result;
  }

  static List<int> bech32HrpExpand(String hrp) {
    ///"""Expand the HRP into values for checksum computation."""
    var codes = hrp.codeUnits;
    var result1 = codes.map((e) => e >> 5).toList();
    var result2 = codes.map((e) => e & 31).toList();
    return result1 + [0] + result2;
  }

  static int bech32Polymod(List<int> values) {
    ///"""Internal function that computes the Bech32 checksum."""
    var generator = [996825010, 642813549, 513874426, 1027748829, 705979059];
    var chk = 1;

    for (var value in values) {
      var top = chk >> 25;
      chk = (chk & 33554431) << 5 ^ value;
      for (var i in Iterable.generate(5)) {
        chk ^= ((top >> i) & 1) != 0 ? generator[i] : 0;
      }
    }
    return chk;
  }

  static List<int> decodePuzzleHash(String address) {
    var data = bech32Decode(address).elementAt(1);
    if (data == null) {
      throw Exception("Error, Invalid Address");
    }
    var decoded = convertbits(data, 5, 8, pad: false);
    return decoded;
  }
}
