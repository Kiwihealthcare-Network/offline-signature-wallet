import 'package:safebox/util/util.dart';
import 'package:convert/convert.dart';

import 'ec.dart';

class Fq {
  /// """
  /// Represents an element of a finite field mod a prime q.
  /// """

  final BigInt q;
  final BigInt value;
  final int extension = 1;
  Fq(this.q, BigInt value) : value = value % q;

  factory Fq.fromBytes(List<int> bytes, BigInt q) {
    if (bytes.length != 48) {
      throw Exception('Error, Error, Point must be 48 bytes');
    }
    final hexString = hex.encode(bytes);
    return Fq(q, BigInt.parse(hexString, radix: 16));
  }

  factory Fq.yForx(Fq x, Type type) {
    ///"""
    /// Solves y = sqrt(x^3 + ax + b) for both valid ys
    /// """
    if (x.runtimeType != type) {
      throw Exception('Error');
    }
    final u = x * x * x + x * EC.a + EC.b;
    final y = u.modSqrt();
    final affinePoint = AffinePoint(x: x, y: y, infinity: false, type: type);
    // ignore: unrelated_type_equality_checks
    if (!affinePoint.isOnCurve()) {
      throw Exception('Error, "No y for point x"');
    }
    return y;
  }

  static Fq zero(BigInt q) => Fq(q, BigInt.from(0));

  static Fq one(BigInt q) => Fq(q, BigInt.from(1));

  String get valueHex => Util.toHex(value);

  String get qHex => Util.toHex(q);

  static bool signFq(Fq element) {
    return element > Fq(EC.q, (EC.q - BigInt.from(1)) ~/ BigInt.from(2));
  }

  List<int> toBytes() => Util.toBytes(value, length: 48);

  Fq modSqrt() {
    if (value == BigInt.from(0)) {
      return Fq(q, BigInt.from(0));
    }
    final big0 = BigInt.from(0);
    final big1 = BigInt.from(1);
    final big2 = BigInt.from(2);
    final big3 = BigInt.from(3);
    final big4 = BigInt.from(4);
    final big5 = BigInt.from(5);
    final big8 = BigInt.from(8);

    if (value.modPow(((q - big1) ~/ big2), q) != big1) {
      throw Exception('No sqrt exists');
    }
    if (q % big4 == big3) {
      return Fq(q, value.modPow(((q + big1) ~/ big4), q));
    }
    if (q % big8 == big5) {
      return Fq(q, value.modPow(((q + big3) ~/ big8), q));
    }
    var s = big0;
    var qNew = q - big1;
    while (qNew % big2 == big0) {
      qNew = qNew ~/ big2;
      s += big1;
    }
    var z = big0;
    for (var i = big0; i < q; i += big1) {
      var euler = i.modPow((q - big1) ~/ big2, q);
      if (euler == BigInt.from(-1) % q) {
        z = i;
        break;
      }
    }
    var m = s;
    var c = z.modPow(qNew, q);
    var t = value.modPow(qNew, q);
    var r = value.modPow((qNew + big1) ~/ big2, q);
    var i = big0;
    var f = big0;
    var b = big0;
    while (true) {
      if (t == big0) {
        return Fq(q, big0);
      }
      if (t == big1) {
        return Fq(q, r);
      }
      i = big0;
      f = t;
      while (f != big1) {
        f = f.modPow(big2, q);
        i += big1;
      }
      b = c.modPow(big2.modPow(m - i - big1, q), q);
      m = i;
      c = b.modPow(big2, q);
      t = (t * c) % q;
      r = (r * b) % q;
    }
  }

  factory Fq.fromFq(BigInt q, Fq fq) {
    return fq;
  }

  Fq pow(dynamic other) {
    if (other is int) {
      if (other == 0) {
        return Fq(this.q, BigInt.one);
      } else if (other == 1) {
        return Fq(this.q, this.value);
      } else if (other % 2 == 0) {
        return Fq(this.q, this.value * this.value).pow(other ~/ 2);
      } else {
        return Fq(this.q, this.value * this.value).pow(other ~/ 2) * this;
      }
    } else if (other is BigInt) {
      if (other == BigInt.zero) {
        return Fq(this.q, BigInt.one);
      } else if (other == BigInt.one) {
        return Fq(this.q, this.value);
      } else if (other % BigInt.two == BigInt.zero) {
        return Fq(this.q, this.value * this.value).pow(other ~/ BigInt.two);
      } else {
        return Fq(this.q, this.value * this.value).pow(other ~/ BigInt.two) *
            this;
      }
    } else {
      throw Exception('Error, Not support type');
    }
  }

  Fq operator -(Fq other) {
    return Fq(q, this.value - other.value);
  }

  Fq operator +(Fq other) {
    return Fq(q, this.value + other.value);
  }

  Fq operator *(Fq other) {
    return Fq(q, this.value * other.value);
  }

  Fq operator ~() {
    /// """
    /// Extended euclidian algorithm for inversion.
    /// """
    var x0 = BigInt.from(1);
    var x1 = BigInt.from(0);
    var a = q;
    var b = value;
    var qNew = BigInt.from(0);
    while (a != BigInt.from(0)) {
      qNew = b ~/ a;
      var bOld = b;
      b = a;
      a = bOld % a;
      var x0Old = x0;
      x0 = x1;
      x1 = x0Old - qNew * x1;
    }
    return Fq(q, x0);
  }

  Fq operator /(Fq other) {
    return this * (~other);
  }

  bool operator >(Fq other) {
    return this.value > other.value;
  }

  Fq operator -() {
    return Fq(q, -value);
  }

  @override
  operator ==(other) =>
      other is Fq &&
      this.value == other.value &&
      this.q == other.q &&
      this.extension == other.extension;

  @override
  String toString() => 'Fq(value: $valueHex)';

  @override
  // ignore: unnecessary_overrides
  int get hashCode => super.hashCode;
}

class Fq2 {
  late Fq root;
  late BigInt q;
  late Iterable<Fq> fqs;
  final int extension = 2;
  final int embedding = 2;
  final Type baseField = Fq;

  Fq2(
    this.q,
    Iterable<dynamic> args,
  ) {
    var argExtension = 0;
    late Iterable<Fq> newArgs;

    try {
      argExtension = args.elementAt(0).extension;
      args.elementAt(1).extension;
      newArgs = Iterable.generate(
          args.length, (index) => args.elementAt(index) as Fq);
    } catch (exp) {
      if (args.length != 2) {
        throw Exception('Error, Invalid number of arguments');
      }
      argExtension = 1;
      newArgs = Iterable.generate(
          args.length, (index) => Fq(EC.q, args.elementAt(index)));
    }
    if (argExtension != 1) {
      if (args.length != this.embedding) {
        throw Exception('Error, Invalid number of arguments');
      }
      for (var arg in newArgs) {
        assert(arg.extension == argExtension);
      }
    }
    assert(newArgs.every((element) => element.runtimeType == baseField));
    fqs = newArgs;
    this.root = Fq(q, BigInt.from(-1));
  }

  String get qHex => Util.toHex(q);

  List<int> toBytes() {
    var bytes = <int>[];
    for (var i = this.fqs.length - 1; i >= 0; i--) {
      var x = this.fqs.elementAt(i);
      if (x.runtimeType != Iterable && x.runtimeType != Fq) {
        x = Fq.fromFq(this.q, x);
      }
      bytes += x.toBytes();
    }
    return bytes;
  }

  String toHex() => Util.toHex(toBytes());

  factory Fq2.fromBytes(List<int> buffer, BigInt q) {
    assert(buffer.length == 2 * 48);
    var embeddedSize = 48 * (2 ~/ 2);
    var tup = [];
    for (var i in Iterable.generate(2)) {
      tup.add(buffer.sublist(i * embeddedSize, (i + 1) * embeddedSize));
    }
    return Fq2(q, tup.reversed.map<Fq>((b) => Fq.fromBytes(b, q)));
  }

  factory Fq2.yForx(Fq2 x, Type type) {
    ///"""
    /// Solves y = sqrt(x^3 + ax + b) for both valid ys
    /// """
    if (x.runtimeType != type) {
      throw Exception('Error');
    }
    final u = x * x * x + x * EC.a + EC.b;
    final y = u.modSqrt();
    final affinePoint = AffinePoint(x: x, y: y, infinity: false, type: type);
    // ignore: unrelated_type_equality_checks
    if (y == BigInt.from(0) || !affinePoint.isOnCurve()) {
      throw Exception('Error, "No y for point x"');
    }
    return y;
  }

  Fq2 modSqrt() {
    //Using algorithm 8 (complex method) for square roots in
    //https://eprint.iacr.org/2012/685.pdf
    //This is necessary for computing y value given an x value.
    var a0 = this.fqs.elementAt(0);
    var a1 = this.fqs.elementAt(1);
    if (a1 == Fq.zero(this.q)) {
      throw Exception('Error');
    }
    var alpha = a0 * a0 + a1 * a1;
    var gamma = alpha.pow((this.q - BigInt.one) ~/ BigInt.two);
    if (gamma == Fq(this.q, BigInt.from(-1))) {
      throw Exception('Error, No sqrt exists');
    }
    alpha = alpha.modSqrt();
    var delta = (a0 + alpha) * ~Fq(this.q, BigInt.two);
    gamma = delta.pow((this.q - BigInt.one) ~/ BigInt.two);
    if (gamma == Fq(this.q, BigInt.from(-1))) {
      delta = (a0 - alpha) * ~Fq(this.q, BigInt.two);
    }
    var x0 = delta.modSqrt();
    var x1 = a1 * ~(Fq(this.q, BigInt.two) * x0);
    return Fq2(this.q, [x0, x1]);
  }

  static Fq2 one(BigInt q) {
    return fromFq(q, Fq(q, BigInt.one));
  }

  static Fq2 zero(BigInt q) {
    return fromFq(q, Fq(q, BigInt.zero));
  }

  void setRoot(Fq root) {
    this.root = root;
  }

  static Fq2 fromFq(BigInt q, Fq fq) {
    var y = Fq.fromFq(q, fq);
    var z = Fq.zero(q);
    var ret = Fq2(q, [y, z]);
    return ret;
  }

  Fq2 pow(dynamic other) {
    var ans = one(this.q);
    var base = this.copyWith();
    ans.root = this.root;
    if (other is int) {
      while (other != 0) {
        if (other & 1 != 0) {
          ans *= base;
        }
        base *= base;
        other >>= 1;
      }
      return ans;
    } else if (other is BigInt) {
      while (other != BigInt.zero) {
        if (other & BigInt.one != BigInt.zero) {
          ans *= base;
        }
        base *= base;
        other >>= 1;
      }
      return ans;
    } else {
      throw Exception('Error');
    }
  }

  Fq2 operator *(dynamic other) {
    if (other.runtimeType == int) {
      throw Exception('Error, NotImplemented');
      // var ret = this.copyWith();
      // ret.fqs = Iterable.generate(
      //     this.fqs.length, (index) => fqs.elementAt(index) * other);
      // ret.q = this.q;
      // ret.root == this.root;
      // return ret;
    }
    if (this.extension < other.extension) {
      throw Exception('Error, NotImplemented');
    }
    var buf = this.fqs.map((e) => Fq.zero(this.q)).toList();
    for (var i = 0; i < this.fqs.length; i++) {
      var x = this.fqs.elementAt(i);
      if (this.extension == other.extension) {
        for (var j = 0; j < other.fqs.length; j++) {
          var y = other.fqs.elementAt(j);
          if (i + j >= this.embedding) {
            buf[(i + j) % this.embedding] += x * y * this.root;
          } else {
            buf[(i + j) % this.embedding] += x * y;
          }
        }
      } else {
        buf[i] = x * other;
      }
    }
    var ret = this.copyWith();
    ret.fqs = Iterable.generate(buf.length, (index) => buf[index]);
    ret.q = this.q;
    ret.root = this.root;
    return ret;
  }

  Fq2 operator +(dynamic other) {
    var ret = this.copyWith();
    if (other.runtimeType != Fq2) {
      var otherNew = this.fqs.map((e) => Fq.zero(q)).toList();
      otherNew[0] = otherNew[0] + other;
      var dataCompare = _zip(this.fqs, otherNew);
      ret.fqs = Iterable.generate(dataCompare.length, (index) {
        var a = dataCompare.elementAt(index).elementAt(0);
        var b = dataCompare.elementAt(index).elementAt(1);
        return a + b;
      });
    } else {
      var dataCompare = _zip(this.fqs, other.fqs);
      ret.fqs = Iterable.generate(dataCompare.length, (index) {
        var a = dataCompare.elementAt(index).elementAt(0);
        var b = dataCompare.elementAt(index).elementAt(1);
        return a + b;
      });
    }
    ret.q = this.q;
    ret.root = this.root;
    return ret;
  }

  Fq2 operator -(dynamic other) {
    return this + (-other);
  }

  Fq2 operator /(Fq2 other) {
    return this * (~other);
  }

  Fq2 operator -() {
    var ret = this.copyWith();
    ret.fqs = Iterable.generate(
        this.fqs.length, (index) => -this.fqs.elementAt(index));
    ret.q = this.q;
    ret.root = this.root;
    return ret;
  }

  static bool signFq2(Fq2 element) {
    if (element.fqs.elementAt(1) == Fq(EC.q, BigInt.zero)) {
      return Fq.signFq(element.fqs.elementAt(0));
    }
    return element.fqs.elementAt(1) >
        Fq(EC.q, (EC.q - BigInt.one) ~/ BigInt.two);
  }

  @override
  operator ==(other) {
    if (other.runtimeType != Fq2) {
      if (other.runtimeType == int || other.runtimeType == BigInt) {
        for (var i in Iterable.generate(this.embedding)) {
          if (this.fqs.elementAt(i) != Fq.zero(this.q)) {
            return false;
          }
        }
        return this.fqs.elementAt(0) == other;
      }
      throw Exception('Error');
    } else {
      return (other is Fq2 &&
          this.fqs.length == other.fqs.length &&
          Iterable.generate(this.fqs.length).every((index) =>
              this.fqs.elementAt(index) == other.fqs.elementAt(index)) &&
          this.q == other.q);
    }
  }

  Fq2 operator ~() {
    // Fq2 is constructed as Fq(u) / (u2 - β) where β = -1
    var a = this.fqs.elementAt(0);
    var b = this.fqs.elementAt(1);
    var factor = ~(a * a + b * b);
    var ret = Fq2(this.q, [a * factor, -b * factor]);
    return ret;
  }

  static List<List<Fq>> _zip(Iterable<Fq> str1, Iterable<Fq> str2) {
    var result = <List<Fq>>[];
    for (var i = 0; i < str1.length; i++) {
      if (i >= str2.length) {
        return result;
      }
      result.add([str1.elementAt(i), str2.elementAt(i)]);
    }
    return result;
  }

  @override
  String toString() {
    return 'Fq2($fqs)';
  }

  Fq2 copyWith() {
    return Fq2(this.q, this.fqs);
  }

  @override
  // ignore: unnecessary_overrides
  int get hashCode => super.hashCode;
}
