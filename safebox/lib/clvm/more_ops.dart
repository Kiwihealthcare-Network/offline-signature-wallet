import 'package:safebox/core/bytes_io.dart';
import 'package:safebox/core/costs.dart';
import 'package:safebox/core/ec.dart';
import 'package:safebox/core/fields.dart';
import 'package:safebox/util/util.dart';
import 'package:safebox/wallet/private_key.dart';
import 'package:crypto/crypto.dart';

import 'sexp.dart';

class MoreOPs {
  static Map<String, Function?> get keyToFunction => {
        "op_add": opAdd,
        "op_subtract": opSubtract,
        "op_multiply": opMultiply,
        "op_div": opDiv,
        "op_gr": opGr,
        "op_gr_bytes": opGrBytes,
        "op_sha256": opSha256,
        "op_substr": opSubStr,
        "op_strlen": opStrlen,
        "op_concat": opConcat,
        "op_divmod": opDivmod,
        "op_ash": opAsh,
        "op_lsh": opLsh,
        "op_logand": opLogand,
        "op_logior": opLogior,
        "op_logxor": opLogxor,
        "op_lognot": opLognot,
        "op_point_add": opPointAdd,
        "op_pubkey_for_exp": opPubkeyForExp,
        "op_not": opNot,
        "op_any": opAny,
        "op_all": opAll,
        "op_softfork": opSoftFork,
      };

  static Iterable<dynamic> mallocCost(BigInt cost, dynamic args) {
    return Tupple.iterable2(
        cost + BigInt.from(args.atom!.length) * Cost.MALLOC_COST_PER_BYTE,
        args);
  }

  static Iterable<dynamic> opSha256(dynamic args) {
    var cost = Cost.SHA256_BASE_COST;
    var argLen = 0;
    var atomBytes = <int>[];
    for (var _ in args.asIter()) {
      var atom = _.atom;
      if (atom == null) {
        throw Exception('Error, sha256 on list $args');
      }
      argLen += atom.length as int;
      cost += Cost.SHA256_COST_PER_ARG;
      atomBytes += atom;
    }
    cost += BigInt.from(argLen) * Cost.SHA256_COST_PER_BYTE;
    return mallocCost(cost, args.toIternal(sha256.convert(atomBytes).bytes));
  }

  static Iterable<Iterable<BigInt>> argsAsBigInts(
      String opName, dynamic args) sync* {
    for (var _ in args.asIter()) {
      if (_.pair != null && _.pair!.isNotEmpty) {
        throw Exception('Error, requires int $args');
      }
      yield Tupple.iterable2<BigInt>(_.asBigInt(), BigInt.from(_.atom!.length));
    }
  }

  static Iterable<BigInt> argsAsInt32(String opName, dynamic args) sync* {
    for (var _ in args.asIter()) {
      if (_.pair != null && _.pair!.isNotEmpty) {
        throw Exception('Error, requires int $args');
      }
      if (_.atom!.length > 4) {
        throw Exception(
            'Error, requires int32 args (with no leading zeros) $args');
      }
      yield _.asBigInt() as BigInt;
    }
  }

  static List<Iterable<BigInt>> argsAsBigIntList(
    String opName,
    dynamic args,
    int count,
  ) {
    var intList = argsAsBigInts(opName, args).toList();
    if (intList.length != count) {
      var plural = count != 1 ? 's' : '';
      throw Exception('Error, takes exactly $args $plural');
    }
    return intList;
  }

  static Iterable<dynamic> argsAsBools(String opName, dynamic args) sync* {
    for (var _ in args.asIter()) {
      var v = args.atom;
      if (v == null || v == [0]) {
        yield args.getFalse();
      } else {
        yield args.getTrue();
      }
    }
  }

  static List<dynamic> argrsAsBoolList(String opName, dynamic args, int count) {
    var boolList = argsAsBools(opName, args).toList();
    if (boolList.length != count) {
      var plural = count != 1 ? 's' : '';
      throw Exception('Error, takes exactly $args $plural');
    }
    return boolList;
  }

  static Iterable<dynamic> opAdd(dynamic args) {
    var total = BigInt.zero;
    var cost = Cost.ARITH_BASE_COST;
    var argsSize = BigInt.zero;
    argsAsBigInts('+', args).forEach((element) {
      total += element.elementAt(0);
      argsSize += element.elementAt(1);
      cost += Cost.ARITH_COST_PER_ARG;
    });
    cost += argsSize * Cost.ARITH_COST_PER_BYTE;
    return mallocCost(cost, args.toIternal(total));
  }

  static Iterable<dynamic> opSubtract(dynamic args) {
    var cost = Cost.ARITH_BASE_COST;
    if (args.nullp()) {
      return mallocCost(cost, args.toIternal(0));
    }
    var sign = BigInt.one;
    var total = BigInt.zero;
    var argSize = BigInt.zero;
    argsAsBigInts('-', args).forEach((element) {
      total += sign * element.elementAt(0);
      sign = BigInt.from(-1);
      argSize += element.elementAt(1);
      cost += Cost.ARITH_COST_PER_ARG;
    });
    cost += argSize * Cost.ARITH_COST_PER_BYTE;
    return mallocCost(cost, args.toIternal(total));
  }

  static Iterable<dynamic> opMultiply(dynamic args) {
    var cost = Cost.MUL_BASE_COST;
    var operand = argsAsBigInts('*', args);
    var operandIterator = operand.iterator;
    var v = BigInt.zero;
    var vs = BigInt.zero;
    try {
      operandIterator.moveNext();
      var result = operandIterator.current;
      v = result.elementAt(0);
      vs = result.elementAt(1);
    } catch (exp) {
      return mallocCost(cost, args.toIternal(1));
    }

    for (var element in operand) {
      var r = element.elementAt(0);
      var rs = element.elementAt(1);
      cost += (rs + vs) * Cost.MUL_LINEAR_COST_PER_BYTE;
      cost += (rs * vs) ~/ Cost.MUL_SQUARE_COST_PER_BYTE_DIVIDER;
      v = v * r;
      vs = Util.limbsForBigInt(v);
    }
    return mallocCost(cost, args.toIternal(v));
  }

  static Iterable<dynamic> opDivmod(SExp args) {
    var cost = Cost.DIVMOD_BASE_COST;
    var data = argsAsBigIntList('divmod', args, 2);
    var il0 = data[0];
    var il1 = data[1];
    var i0 = il0.elementAt(0);
    var l0 = il0.elementAt(1);
    var i1 = il1.elementAt(0);
    var l1 = il1.elementAt(1);
    if (i1 == BigInt.zero) {
      throw Exception('Error, divmod with 0 $args');
    }
    cost += (l0 + l1) * Cost.DIVMOD_COST_PER_BYTE;
    var q = i0 ~/ i1;
    var r = i0 % i1;
    var q1 = args.toIternal(q);
    var r1 = args.toIternal(r);
    cost += (BigInt.from(q1.atom!.length) + BigInt.from(r1.atom!.length)) *
        Cost.MALLOC_COST_PER_BYTE;
    return Tupple.iterable2(cost, args.toIternal(Tupple.iterable2(q, r)));
  }

  static opDiv(dynamic args) {
    var cost = Cost.DIV_BASE_COST;
    var data = argsAsBigIntList('/', args, 2);
    var il0 = data[0];
    var il1 = data[1];
    var i0 = il0.elementAt(0);
    var l0 = il0.elementAt(1);
    var i1 = il1.elementAt(0);
    var l1 = il1.elementAt(1);
    if (i1 == BigInt.zero) {
      throw Exception('Error, div with 0 $args');
    }
    cost += (l0 + l1) * Cost.DIVMOD_COST_PER_BYTE;
    var q = i0 ~/ i1;
    return mallocCost(cost, args.toIternal(q));
  }

  static opGr(dynamic args) {
    var cost = Cost.GR_BASE_COST;
    var data = argsAsBigIntList('>', args, 2);
    var il0 = data[0];
    var il1 = data[1];
    var i0 = il0.elementAt(0);
    var l0 = il0.elementAt(1);
    var i1 = il1.elementAt(0);
    var l1 = il1.elementAt(1);
    cost += (l0 + l1) * Cost.GR_COST_PER_BYTE;
    return Tupple.iterable2(cost, i0 > i1 ? args.getTrue() : args.getFalse());
  }

  static Iterable<dynamic> opGrBytes(dynamic args) {
    var argList = args.asIter().toList();
    if (argList.length != 2) {
      throw Exception('Error,>s takes exactly 2 arguments $args');
    }
    var a0 = argList.elementAt(0);
    var a1 = argList.elementAt(1);
    if ((a0.pair != null && a0.pair!.isNotEmpty) ||
        (a1.pair != null && a1.pair!.isNotEmpty)) {
      throw Exception('Error,>s on list $args');
    }
    var b0 = a0.atom;
    var b1 = a1.atom;
    var cost = Cost.GRS_BASE_COST;
    cost += BigInt.from(b0!.length + b1!.length) * Cost.GRS_COST_PER_BYTE;
    return Tupple.iterable2(cost, b0 > b1 ? args.getTrue() : args.getFalse());
  }

  static opPubkeyForExp(dynamic args) {
    var data = argsAsBigIntList('pubkey_for_exp', args, 1);
    var il0 = data.elementAt(0);
    var i0 = il0.elementAt(0);
    var l0 = il0.elementAt(1);
    var a = BigInt.parse(
        '73EDA753299D7D483339D80809A1D80553BDA402FFFE5BFEFFFFFFFF00000001',
        radix: 16);
    i0 %= a;
    var exponent = PrivateKey(key: i0.toRadixString(16));
    try {
      var r = args.toIternal(exponent.getPublicKeyPointWallet().toBytes());
      var cost = Cost.PUBKEY_BASE_COST;
      cost += l0 * Cost.PUBKEY_COST_PER_BYTE;
      return mallocCost(cost, r);
    } catch (exp) {
      throw Exception('Error,problem in op_pubkey_for_exp: $args');
    }
  }

  static Iterable<dynamic> opPointAdd(dynamic args) {
    var cost = Cost.POINT_ADD_BASE_COST;
    var i = 0;
    late JacobianPoint p;
    for (var _ in args.asIter()) {
      if (_.pair != null && _.pair!.isNotEmpty) {
        throw Exception('Error, point_add on list: $args');
      }
      try {
        if (i == 0) {
          p = JacobianPoint.fromBytes(_.atom!, Fq);
        } else {
          p += JacobianPoint.fromBytes(_.atom!, Fq);
        }
        i += 1;
        cost += Cost.POINT_ADD_COST_PER_ARG;
      } catch (exp) {
        throw Exception('Error,point_add expects blob, got: $args');
      }
    }
    return mallocCost(cost, args.toIternal(p));
  }

  static Iterable<dynamic> opStrlen(dynamic args) {
    if (args.listLen() != 1) {
      throw Exception('Error, strlen takes exactly 1 argument: $args');
    }
    var a0 = args.first();
    if (a0.pair != null && a0.pair!.isNotEmpty) {
      throw Exception('Error, strlen on list: $args');
    }
    var size = a0.atom!.length;
    var cost =
        Cost.STRLEN_BASE_COST + BigInt.from(size) * Cost.STRLEN_COST_PER_BYTE;
    return mallocCost(cost, args.toIternal(size));
  }

  static Iterable<dynamic> opSubStr(dynamic args) {
    var argCount = args.listLen();
    if (![2, 3].contains(argCount)) {
      throw Exception('ubstr takes exactly 2 or 3 arguments: $args');
    }
    var a0 = args.first();
    if (a0.pair != null && a0.pair!.isNotEmpty) {
      throw Exception('Error, substr on list: $args');
    }
    var s0 = a0.atom;
    var i1 = BigInt.zero;
    var i2 = BigInt.zero;
    if (argCount == 2) {
      i1 = argsAsInt32('substr', args.rest()).toList().elementAt(0);
      i2 = BigInt.from(s0!.length);
    } else {
      var data = argsAsInt32('substr', args.rest()).toList();
      i1 = data.elementAt(0);
      i2 = data.elementAt(1);
    }

    if (i2 > BigInt.from(s0!.length) ||
        i2 < i1 ||
        i2 < BigInt.zero ||
        i1 < BigInt.zero) {
      throw Exception('Error, invalid indices for substr: $args');
    }
    var s = s0.sublist(i1.toInt(), i2.toInt());
    var cost = BigInt.one;
    return Tupple.iterable2(cost, args.toIternal(s));
  }

  static Iterable<dynamic> opConcat(dynamic args) {
    var cost = Cost.CONCAT_BASE_COST;
    var s = ByteIo(pointer: 0, bytes: []);
    for (var _ in args.asIter()) {
      if (_.pair != null && _.pair!.isNotEmpty) {
        throw Exception('Error, concat on list: $args');
      }
      s.write(_.atom!);
      cost += Cost.CONCAT_COST_PER_ARG;
    }
    var r = s.bytes;
    cost += BigInt.from(r.length) * Cost.CONCAT_COST_PER_BYTE;
    return Tupple.iterable2(cost, args.toIternal(r));
  }

  static Iterable<dynamic> opAsh(dynamic args) {
    var data = argsAsBigIntList('ash', args, 2);
    var il0 = data.elementAt(0);
    var il1 = data.elementAt(1);
    var i0 = il0.elementAt(0);
    var l0 = il0.elementAt(1);
    var i1 = il1.elementAt(0);
    var l1 = il1.elementAt(1);
    if (l1 > BigInt.from(4)) {
      throw Exception(
          'Error, ash requires int32 args (with no leading zeros) $args');
    }
    if (i1.abs() > BigInt.from(65535)) {
      throw Exception('Error, shift too large $args');
    }
    var r = BigInt.zero;
    if (i1 >= BigInt.zero) {
      r = i0 << i1.toInt();
    } else {
      r = i0 >> -i1.toInt();
    }
    var cost = Cost.ARITH_BASE_COST;
    cost += (l0 + Util.limbsForBigInt(r)) * Cost.ARITH_COST_PER_BYTE;
    return Tupple.iterable2(cost, args.toIternal(r));
  }

  static Iterable<dynamic> opLsh(dynamic args) {
    var data = argsAsBigIntList('lsh', args, 2);
    var il0 = data.elementAt(0);
    var il1 = data.elementAt(1);
    var i0 = il0.elementAt(0);
    var l0 = il0.elementAt(1);
    var i1 = il1.elementAt(0);
    var l1 = il1.elementAt(1);
    if (l1 > BigInt.from(4)) {
      throw Exception(
          'Error, lsh requires int32 args (with no leading zeros) $args');
    }
    if (i1.abs() > BigInt.from(65535)) {
      throw Exception('Error, shift too large $args');
    }
    var a0 = args.atom;
    i0 = Util.toBigInt(a0!);
    var r = BigInt.zero;
    if (i1 >= BigInt.zero) {
      r = i0 << i1.toInt();
    } else {
      r = i0 >> -i1.toInt();
    }
    var cost = Cost.LSHIFT_BASE_COST;
    cost += (l0 + Util.limbsForBigInt(r)) * Cost.LSHIFT_COST_PER_BYTE;
    return Tupple.iterable2(cost, args.toIternal(r));
  }

  static Iterable<dynamic> binopReduction(
    String opName,
    BigInt initialValue,
    dynamic args,
    Function opF,
  ) {
    var total = initialValue;
    var argsSize = BigInt.zero;
    var cost = Cost.LOG_BASE_COST;
    for (var _ in argsAsBigInts(opName, args)) {
      var r = _.elementAt(0);
      var l = _.elementAt(1);
      total = opF(total, r);
      argsSize += l;
      cost += Cost.LOG_COST_PER_ARG;
    }
    cost += argsSize * Cost.LOG_COST_PER_BYTE;
    return Tupple.iterable2(cost, args.toIternal(total));
  }

  static Iterable<dynamic> opLogand(dynamic args) {
    BigInt binop(BigInt a, BigInt b) {
      a &= b;
      return a;
    }

    return binopReduction('logand', BigInt.from(-1), args, binop);
  }

  static Iterable<dynamic> opLogior(dynamic args) {
    BigInt binop(BigInt a, BigInt b) {
      a |= b;
      return a;
    }

    return binopReduction('logior', BigInt.zero, args, binop);
  }

  static Iterable<dynamic> opLogxor(dynamic args) {
    BigInt binop(BigInt a, BigInt b) {
      a ^= b;
      return a;
    }

    return binopReduction('logxor', BigInt.zero, args, binop);
  }

  static Iterable<dynamic> opLognot(dynamic args) {
    var il0 = argsAsBigIntList('lognot', args, 1).elementAt(0);
    var i0 = il0.elementAt(0);
    var l0 = il0.elementAt(1);
    var cost = Cost.LOGNOT_BASE_COST + l0 * Cost.LOGNOT_COST_PER_BYTE;
    return mallocCost(cost, args.toIternal(~i0));
  }

  static Iterable<dynamic> opNot(dynamic args) {
    var i0 = argrsAsBoolList('not', args, 1).elementAt(0);
    late final dynamic r;
    if (i0.atom.isEmpty) {
      r = args.getTrue();
    } else {
      r = args.getFalse();
    }
    var cost = Cost.BOOL_BASE_COST;
    return Tupple.iterable2(cost, args.toIternal(r));
  }

  static Iterable<dynamic> opAny(dynamic args) {
    var items = argsAsBools('any', args).toList();
    var cost = Cost.BOOL_BASE_COST +
        BigInt.from(items.length) * Cost.BOOL_COST_PER_ARG;
    var r = args.getFalse();
    for (var v in items) {
      if (v.atom.isNotEmpty()) {
        r = args.getTrue();
        break;
      }
    }
    return Tupple.iterable2(cost, args.toIternal(r));
  }

  static Iterable<dynamic> opAll(dynamic args) {
    var items = argsAsBools('all', args).toList();
    var cost = Cost.BOOL_BASE_COST +
        BigInt.from(items.length) * Cost.BOOL_COST_PER_ARG;
    var r = args.getTrue();
    for (var v in items) {
      if (v.atom.isEmpty()) {
        r = args.getFalse();
        break;
      }
    }
    return Tupple.iterable2(cost, args.toIternal(r));
  }

  static Iterable<dynamic> opSoftFork(dynamic args) {
    if (args.listLen() < 1) {
      throw Exception('Error, softfork takes at least 1 argument');
    }
    var a = args.first();
    if (a.pair != null && a.pair!.isNotEmpty) {
      throw Exception('Error, softfork requires int args');
    }
    var cost = a.asBigInt();
    if (cost < BigInt.one) {
      throw Exception('Error, cost must be > 0');
    }
    return Tupple.iterable2(cost, args.getFalse());
  }
}
