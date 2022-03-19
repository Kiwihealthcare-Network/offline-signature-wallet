import 'package:safebox/clvm/sexp.dart';
import 'package:safebox/core/costs.dart';
import 'package:safebox/util/util.dart';

class CoreOps {
  static Map<String, Function?> get keyToFunction => {
        "op_if": opIf,
        "op_cons": opCons,
        "op_first": opFirst,
        "op_rest": opRest,
        "op_listp": opListp,
        "op_raise": opRaise,
        "op_eq": opEq,
      };

  static Iterable<dynamic> opIf(dynamic args) {
    if (args.listLen() != 3) {
      throw Exception('Error, i takes exactly 3 arguments $args');
    }
    var r = args.rest();
    if (args.first().nullp()) {
      return Tupple.iterable2(Cost.IF_COST, r.rest().first());
    }
    return Tupple.iterable2(Cost.IF_COST, r.first());
  }

  static Iterable<dynamic> opCons(dynamic args) {
    if (args.listLen() != 2) {
      throw Exception('Error, c takes exactly 2 arguments $args');
    }
    return Tupple.iterable2(
        Cost.CONS_COST, args.first().cons(args.rest().first()));
  }

  static Iterable<dynamic> opFirst(dynamic args) {
    if (args.listLen() != 1) {
      throw Exception('Error, f takes exactly 1 arguments $args');
    }
    return Tupple.iterable2(Cost.FIRST_COST, args.first().first());
  }

  static Iterable<dynamic> opRest(dynamic args) {
    if (args.listLen() != 1) {
      throw Exception('Error, r takes exactly 1 arguments $args');
    }
    return Tupple.iterable2(Cost.REST_COST, args.first().rest());
  }

  static Iterable<dynamic> opListp(dynamic args) {
    if (args.listLen() != 1) {
      throw Exception('Error, l takes exactly 1 arguments $args');
    }
    return Tupple.iterable2(Cost.REST_COST,
        args.first().listlp() ? args.getTrue() : args.getFalse());
  }

  static dynamic opRaise(dynamic args) {
    throw Exception('Error, clvm raise $args');
  }

  static Iterable<dynamic> opEq(dynamic args) {
    if (args.listLen() != 2) {
      throw Exception('Error, = takes exactly 1 arguments $args');
    }
    var a0 = args.first();
    var a1 = args.rest().first();
    if ((a0.pair != null && a0.pair!.isNotEmpty) ||
        (a1.pair != null && a1.pair!.isNotEmpty)) {
      throw Exception('Error, = on list $a0 $a1');
    }
    var b0 = a0.atom;
    var b1 = a1.atom;
    var cost = Cost.EQ_BASE_COST;
    cost += BigInt.from((b0!.length + b1!.length)) * Cost.EQ_COST_PER_BYTE;
    return Tupple.iterable2(
        cost, Util.compareBytes(b0, b1) ? args.getTrue() : args.getFalse());
  }
}
