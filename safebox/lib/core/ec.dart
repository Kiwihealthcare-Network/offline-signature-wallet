import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:safebox/core/op_swu_g2.dart';
import 'package:safebox/util/util.dart';
import 'package:safebox/wallet/private_key.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'fields.dart';

const G1ELEMENT_DEFAULT =
    '800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';

class EC {
  /// BLS parameter used to generate the other parameters
  /// Spec is found here: https://github.com/zkcrypto/pairing/tree/master/src/bls12_381
  static final x = BigInt.parse('-D201000000010000', radix: 16);

  /// 381 bit prime
  /// Also see fields:bls12381_q
  static final q = BigInt.parse(
      '1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFAAAB',
      radix: 16);

  /// a,b and a2, b2, define the elliptic curve and twisted curve.
  /// y^2 = x^3 + 4
  /// y^2 = x^3 + 4(u + 1)
  static final a = Fq(q, BigInt.from(0));
  static final b = Fq(q, BigInt.from(4));
  static final aTwist = Fq2(q, [BigInt.from(0), BigInt.from(0)]);
  static final bTwist = Fq2(q, [BigInt.from(4), BigInt.from(4)]);

  /// The generators for g1 and g2
  static final gx = Fq(
    q,
    BigInt.parse(
        '17F1D3A73197D7942695638C4FA9AC0FC3688C4F9774B905A14E3A3F171BAC586C55E83FF97A1AEFFB3AF00ADB22C6BB',
        radix: 16),
  );
  static final gy = Fq(
    q,
    BigInt.parse(
        '08B3F481E3AAA0F1A09E30ED741D8AE4FCF5E095D5D00AF600DB18CB2C04B3EDD03CC744A2888AE40CAA232946C5E7E1',
        radix: 16),
  );

  static final g2x = Fq2(q, [
    BigInt.parse(
        '352701069587466618187139116011060144890029952792775240219908644239793785735715026873347600343865175952761926303160'),
    BigInt.parse(
        '3059144344244213709971259814753781636986470325476647558659373206291635324768958432433509563104347017837885763365758'),
  ]);
  static final g2y = Fq2(q, [
    BigInt.parse(
        '1985150602287291935568054521177171638300868978215655730859378665066344726373823718423869104263333984641494340347905'),
    BigInt.parse(
        '927553665492332455747201965776037880757740193453592970025027978793976877002675564980949289727957565575433344219582'),
  ]);

  /// The order of all three groups (g1, g2, and gt). Note, the elliptic curve E_twist
  /// actually has more valid points than this. This is relevant when hashing onto the
  /// curve, where we use a point that is not in g2, and map it into g2.
  static final n = BigInt.parse(
      '73EDA753299D7D483339D80809A1D80553BDA402FFFE5BFEFFFFFFFF00000001',
      radix: 16);

  /// Cofactor used to generate r torsion points
  static final h = BigInt.parse('396C8C005555E1568C00AAAB0000AAAB', radix: 16);

  /// https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-07#section-8.8.2
  static final hEff = BigInt.parse(
      'BC69F08F2EE75B3584C6A0EA91B352888E2A8E9145AD7689986FF031508FFE1329C2F178731DB956D82BF015D1212B02EC0EC69D7477C1AE954CBC06689F6A359894C0ADEBBF6B4E8020005AAA95551',
      radix: 16);

  /// Embedding degree
  static int k = 12;

  /// sqrt(-3) mod q
  static final sqrtN3 = BigInt.parse(
      '1586958781458431025242759403266842894121773480562120986020912974854563298150952611241517463240701');

  /// (sqrt(-3) - 1) / 2 mod q
  static final sqrtN3m1o2 = BigInt.parse(
      '793479390729215512621379701633421447060886740281060493010456487427281649075476305620758731620350');
}

class AffinePoint {
  /// """
  /// Elliptic curve point, can represent any curve, and use Fq or Fq2
  /// coordinates.
  /// """

  final dynamic x;
  final dynamic y;
  final bool infinity;
  final Type type;
  AffinePoint({
    required this.x,
    required this.y,
    required this.infinity,
    required this.type,
  });

  factory AffinePoint.g1() =>
      AffinePoint(x: EC.gx, y: EC.gy, infinity: false, type: Fq);

  factory AffinePoint.g2() =>
      AffinePoint(x: EC.g2x, y: EC.g2y, infinity: false, type: Fq2);

  bool isOnCurve() {
    /// """
    /// Check that y^2 = x^3 + ax + b
    /// """
    if (infinity) {
      return true;
    }
    final left = y * y;
    final right = x * x * x + EC.a * x + EC.b;
    return left == right;
  }

  JacobianPoint toJacobianPoin() => JacobianPoint(
        x: x,
        y: y,
        z: type == Fq ? Fq.one(EC.q) : Fq2.one(EC.q),
        infinity: infinity,
        type: type,
      );

  @override
  String toString() {
    return 'AffinePoint(x: $x, y: $y, infinity: $infinity, type: $type)';
  }
}

class JacobianPoint {
  ///  """
  /// Elliptic curve point, can represent any curve, and use Fq or Fq2
  /// coordinates. Uses Jacobian coordinates so that point addition
  /// does not require slow inversion.
  /// """

  final dynamic x;
  final dynamic y;
  final dynamic z;
  final bool infinity;
  final Type type;
  JacobianPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.infinity,
    required this.type,
  });

  AffinePoint toAffinePoint() {
    if (infinity) {
      return AffinePoint(
          x: Fq.zero(EC.q), y: Fq.zero(EC.q), infinity: infinity, type: type);
    }

    final xNew = x / (z * z);
    final yNew = y / (z * z * z);
    return AffinePoint(x: xNew, y: yNew, infinity: infinity, type: type);
  }

  int getFingerprint() => bytesToInt(sha256.convert(toBytes()).bytes.sublist(0, 4), Endian.big);

  int bytesToInt(List<int> bytes, Endian endian, {bool signed = false}) {
    if (bytes.isEmpty) {
      return 0;
    }
    var sign = bytes[endian == Endian.little ? bytes.length - 1 : 0]
        .toRadixString(2)
        .padLeft(8, '0')[0];
    var byteList = (endian == Endian.little ? bytes.reversed : bytes).toList();
    var binary =
    byteList.map((byte) => byte.toRadixString(2).padLeft(8, '0')).join('');
    if (sign == '1' && signed) {
      binary = (int.parse(flip(binary), radix: 2) + 1)
          .toRadixString(2)
          .padLeft(bytes.length * 8, '0');
    }
    var result = int.parse(binary, radix: 2);
    return sign == '1' && signed ? -result : result;
  }

  String flip(String binary) {
    return binary.replaceAllMapped(
        RegExp(r'[01]'), (match) => match.group(0) == '1' ? '0' : '1');
  }

  factory JacobianPoint.fromBytes(List<int> bytes, Type type) {
    ///  # Zcash serialization described in https://datatracker.ietf.org/doc/draft-irtf-cfrg-pairing-friendly-curves/
    if (type == Fq) {
      if (bytes.length != 48) {
        throw Exception("Error, Point must be 48 bytes");
      }
    } else if (type == Fq2) {
      if (bytes.length != 96) {
        throw Exception("Error, Point must be 96 bytes");
      }
    } else {
      throw Exception("Error,Invalid type, support Fq or Fq2");
    }
    final mBytes = bytes[0] & 224;
    if ([32, 96, 224].contains(mBytes)) {
      throw Exception("Error,Invalid first three bits");
    }

    final cBit = mBytes & 128;
    final iBit = mBytes & 64;
    final sBit = mBytes & 32;
    if (cBit == 0) {
      throw Exception("Error,First bit must be 1 (only compressed points)");
    }
    final buffer = Util.toBytes(bytes[0] & 31) + bytes.sublist(1);
    if (iBit == 1) {
      if (buffer.every((element) => element != 0)) {
        throw Exception('Point at infinity set, but data not all zeroes');
      }
      if (type == Fq) {
        return AffinePoint(
                x: Fq.zero(EC.q), y: Fq.zero(EC.q), infinity: true, type: type)
            .toJacobianPoin();
      } else {
        return AffinePoint(
                x: Fq2.zero(EC.q),
                y: Fq2.zero(EC.q),
                infinity: true,
                type: type)
            .toJacobianPoin();
      }
    }
    final dynamic x =
        type == Fq ? Fq.fromBytes(buffer, EC.q) : Fq2.fromBytes(buffer, EC.q);
    final dynamic yValue =
        type == Fq ? Fq.yForx(x as Fq, type) : Fq2.yForx(x as Fq2, type);
    var sign = false;
    if (type == Fq) {
      sign = Fq.signFq(yValue as Fq);
    } else if (type == Fq2) {
      sign = Fq2.signFq2(yValue as Fq2);
    } else {
      throw Exception('Error, Only support Fq, Fq2');
    }
    late final dynamic y;
    if (sign == (sBit != 0)) {
      y = yValue;
    } else {
      if (yValue is Fq) {
        y = -yValue;
      } else if (yValue is Fq2) {
        y = -yValue;
      } else {
        throw Exception('Error, Only support Fq, Fq2');
      }
    }
    return AffinePoint(
      x: x,
      y: y,
      infinity: false,
      type: type,
    ).toJacobianPoin();
  }

  JacobianPoint doublePointJacobian() {
    ///  """
    /// Jacobian elliptic curve point doubling
    /// http://www.hyperelliptic.org/EFD/oldefd/jacobian.html
    /// """
    final x = this.x;
    final y = this.y;
    final z = this.z;

    if (y.runtimeType == Fq && y == Fq.zero(EC.q) || infinity) {
      return JacobianPoint(
          x: Fq.one(EC.q),
          y: Fq.one(EC.q),
          z: Fq.zero(EC.q),
          infinity: true,
          type: type);
    }
    if (y.runtimeType == Fq2 && y == Fq2.zero(EC.q) || infinity) {
      return JacobianPoint(
          x: Fq2.one(EC.q),
          y: Fq2.one(EC.q),
          z: Fq2.zero(EC.q),
          infinity: true,
          type: type);
    }
    final s = x * y * y * Fq(EC.q, BigInt.from(4));
    final zSq = z * z;
    final z4th = zSq * zSq;
    final ySq = y * y;
    final y4th = ySq * ySq;
    var m = x * x * Fq(EC.q, BigInt.from(3));
    m += (z4th * EC.a);
    final xP = m * m - (s * Fq(EC.q, BigInt.from(2)));
    final yP = m * (s - xP) - (y4th * Fq(EC.q, BigInt.from(8)));
    final zP = y * z * Fq(EC.q, BigInt.from(2));
    return JacobianPoint(x: xP, y: yP, z: zP, infinity: false, type: type);
  }

  List<int> toBytes() {
    final affinePoint = toAffinePoint();
    var output = (affinePoint.x).toBytes();
    if (affinePoint.infinity) {
      return hex.decode('40') +
          List.filled(output.length - 1, hex.decode('00')[0]);
    }
    var sign = false;
    if (type == Fq) {
      sign = Fq.signFq(affinePoint.y);
    } else if (type == Fq2) {
      sign = Fq2.signFq2(affinePoint.y);
    } else {
      throw Exception('Error, Not Support $type');
    }
    if (sign) {
      output[0] |= int.parse('A0', radix: 16);
    } else {
      output[0] |= int.parse('80', radix: 16);
    }
    return output;
  }

  String toHex() {
    return hex.encode(toBytes());
  }

  JacobianPoint operator +(JacobianPoint other) {
    ///"""
    ///Jacobian elliptic curve point addition
    ///http://www.hyperelliptic.org/EFD/oldefd/jacobian.html
    ///"""
    final p1 = this;
    final p2 = other;
    if (p1.infinity) {
      return p2;
    }
    if (p2.infinity) {
      return p1;
    }
    final u1 = p1.x * (p2.z * p2.z);
    final u2 = p2.x * (p1.z * p1.z);
    final s1 = p1.y * (p2.z * p2.z * p2.z);
    final s2 = p2.y * (p1.z * p1.z * p1.z);

    if (u1 == u2) {
      if (s1 != s2) {
        if (p1.type == Fq) {
          return JacobianPoint(
              x: Fq.one(EC.q),
              y: Fq.one(EC.q),
              z: Fq.zero(EC.q),
              infinity: true,
              type: p1.type);
        } else if (p1.type == Fq2) {
          return JacobianPoint(
              x: Fq2.one(EC.q),
              y: Fq2.one(EC.q),
              z: Fq2.zero(EC.q),
              infinity: true,
              type: p1.type);
        }
      } else {
        return doublePointJacobian();
      }
    }
    final h = u2 - u1;
    final r = s2 - s1;
    final hSq = h * h;
    final hCu = h * hSq;
    final x3 = r * r - hCu - (u1 * hSq * Fq(EC.q, BigInt.from(2)));
    final y3 = r * (u1 * hSq - x3) - (s1 * hCu);
    final z3 = h * p1.z * p2.z;
    return JacobianPoint(x: x3, y: y3, z: z3, infinity: false, type: type);
  }

  JacobianPoint operator *(dynamic data) {
    if (data is BigInt || data is Fq) {
      var dataBigInt = BigInt.from(0);
      if (data is Fq) {
        dataBigInt = data.value;
      } else if (data is BigInt) {
        dataBigInt = data;
      }
      if (infinity || dataBigInt % EC.q == BigInt.from(0)) {
        return JacobianPoint(
            x: Fq.one(EC.q),
            y: Fq.one(EC.q),
            z: Fq.zero(EC.q),
            infinity: true,
            type: type);
      }
      var result = JacobianPoint(
          x: Fq.one(EC.q),
          y: Fq.one(EC.q),
          z: Fq.zero(EC.q),
          infinity: true,
          type: type);
      var addend = this;
      while (dataBigInt > BigInt.from(0)) {
        if (dataBigInt & BigInt.from(1) == BigInt.from(1)) {
          result += addend;
        }
        addend += addend;
        dataBigInt = dataBigInt >> 1;
      }
      return result;
    } else {
      throw Exception(
          'Error, must be BigInt or Fq, data plus: ${data.runtimeType}');
    }
  }

  static JacobianPoint G2Infinity() => JacobianPoint(
      x: Fq2.one(EC.q),
      y: Fq2.one(EC.q),
      z: Fq2.zero(EC.q),
      infinity: true,
      type: Fq2);

  bool isOnCurve() {
    if (this.infinity) {
      return true;
    }
    return this.toAffinePoint().isOnCurve();
  }

  void checkValid() {
    // assert(isOnCurve());
    // assert(this * EC.n == G2Infinity());
  }

  @override
  String toString() {
    return 'JacobianPoint(x: $x, y: $y, z: $z, infinity: $infinity)';
  }
}

class AugSchemeMPL {
  static final aug_scheme_dst =
      utf8.encode('BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_AUG_');

  static JacobianPoint sign(
    PrivateKey privateKey,
    List<int> message,
  ) {
    var pk = privateKey.getPublicKeyPointWallet().toBytes();
    return coreSignMpl(privateKey, pk + message, aug_scheme_dst);
  }

  static JacobianPoint coreSignMpl(
    PrivateKey privateKey,
    List<int> message,
    List<int> dst,
  ) {
    return g2Map(message, dst) * privateKey.keyValue;
  }

  static JacobianPoint coreArregateMpl(List<JacobianPoint> signatures) {
    if (signatures.isEmpty) {
      throw Exception('Error, Must aggregate at least 1 signature');
    }
    var aggregate = signatures[0];
    aggregate.checkValid();
    for (var signature in signatures.sublist(1)) {
      signature.checkValid();
      aggregate += signature;
    }
    return aggregate;
  }

  static JacobianPoint aggregate(List<JacobianPoint> signatures) {
    return coreArregateMpl(signatures);
  }
}

JacobianPoint evalIso(
  JacobianPoint p,
  Iterable<Iterable<Fq2>> mapCoeffs,
) {
  var x = p.x as Fq2;
  var y = p.y as Fq2;
  var z = p.z as Fq2;
  var mapVals = List<Fq2?>.filled(4, null);
  // precompute the required powers of Z^2
  var maxOrd = mapCoeffs.map((e) => e.length).toList().reduce(max);
  var zpows = List<Fq2?>.filled(maxOrd, null);
  zpows[0] = z.pow(0);
  zpows[1] = z.pow(2);
  if (zpows.length > 2) {
    for (var idx in Iterable.generate(zpows.length - 2, (index) => index + 2)) {
      assert(zpows[idx - 1] != null);
      assert(zpows[1] != null);
      zpows[idx] = zpows[idx - 1]! * zpows[1]!;
    }
  }
  // compute the numerator and denominator of the X and Y maps via Horner's rule

  for (var idx in Iterable<int>.generate(mapCoeffs.length)) {
    var coeffs = mapCoeffs.elementAt(idx);
    var _compareData =
        _zip(coeffs.toList().reversed, zpows.sublist(0, coeffs.length));
    var coeffsZ = _compareData.map((e) {
      return e[0] * e[1];
    }).toList();
    var tmp = coeffsZ[0];
    for (var coeff in coeffsZ.sublist(1)) {
      tmp *= x;
      tmp += coeff;
    }
    mapVals[idx] = tmp;
  }

  // xden is of order 1 less than xnum, so need to multiply it by an extra factor of Z^2
  assert(mapCoeffs.elementAt(1).length + 1 == mapCoeffs.elementAt(0).length);
  assert(zpows[1] != null);
  assert(mapVals[1] != null);
  mapVals[1] = mapVals[1]! * zpows[1];
  // multiply result of Y map by the y-coordinate y / z^3
  assert(mapVals[2] != null);
  assert(mapVals[3] != null);
  mapVals[2] = mapVals[2]! * y;
  mapVals[3] = mapVals[3]! * z.pow(3);
  var Z = mapVals[1]! * mapVals[3];
  var X = mapVals[0]! * mapVals[3] * Z;
  var Y = mapVals[2]! * mapVals[1] * Z * Z;
  return JacobianPoint(x: X, y: Y, z: Z, infinity: p.infinity, type: Fq2);
}

List<List<Fq2>> _zip(Iterable<Fq2> str1, Iterable<Fq2?> str2) {
  var result = <List<Fq2>>[];
  for (var i = 0; i < str1.length; i++) {
    if (i >= str2.length) {
      return result;
    }
    result.add([str1.elementAt(i), str2.elementAt(i)!]);
  }
  return result;
}
