import 'package:safebox/clvm/core_ops.dart';
import 'package:safebox/clvm/more_ops.dart';
import 'package:safebox/clvm/sexp.dart';
import 'package:safebox/core/costs.dart';
import 'package:safebox/util/util.dart';

// ignore: constant_identifier_names
const KEYWORDSTRING =

    /// core opcodes 0x01-x08
    ". q a i c f r l x "

    /// opcodes on atoms as strings 0x09-0x0f
    "= >s sha256 substr strlen concat . "

    /// opcodes on atoms as ints 0x10-0x17
    "+ - * / divmod > ash lsh "

    // opcodes on atoms as vectors of bools 0x18-0x1c
    "logand logior logxor lognot . "

    // opcodes for bls 1381 0x1d-0x1f
    "point_add pubkey_for_exp . "

    // bool opcodes 0x20-0x23
    "not any all . "

    // misc 0x24
    "softfork";

// ignore: constant_identifier_names
const OP_REWRITE = {
  "+": "add",
  "-": "subtract",
  "*": "multiply",
  "/": "div",
  "i": "if",
  "c": "cons",
  "f": "first",
  "r": "rest",
  "l": "listp",
  "x": "raise",
  "=": "eq",
  ">": "gr",
  ">s": "gr_bytes",
};

class OperatorDict {
  ///  """
  /// This is a nice hack that adds `__call__` to a dictionary, so
  /// operators can be added dynamically.
  /// """
  Map<List<int>, Function>? dict;
  List<int>? quoteAtom;
  List<int>? applyAtom;
  Function? unKnownOpHandler;

  OperatorDict(
    this.dict,
    List<dynamic> args,
    Map<dynamic, dynamic> kwargs,
  ) {
    this.quoteAtom = kwargs.containsKey('quote') ? kwargs['quote'] : null;
    this.applyAtom = kwargs.containsKey('apply') ? kwargs['apply'] : null;
    this.unKnownOpHandler = kwargs.containsKey('unknown_op_handler')
        ? kwargs['unknown_op_handler']
        : defaultUnknownOp;
  }

  // ignore: non_constant_identifier_names
  static final KEYWORKS = KEYWORDSTRING.split(' ');
  // ignore: non_constant_identifier_names
  static final KEYWORK_FROM_ATOM = {
    for (var index in Iterable<int>.generate(KEYWORKS.length))
      [index]: KEYWORKS[index]
  };
  // ignore: non_constant_identifier_names
  static final KEYWORK_TO_ATOM = {
    for (var index in Iterable<int>.generate(KEYWORKS.length))
      KEYWORKS[index]: [index]
  };

  static Iterable<dynamic> defaultUnknownOp(List<int> op, dynamic args) {
    /// any opcode starting with ffff is reserved (i.e. fatal error)
    /// opcodes are not allowed to be empty
    if (op.isEmpty ||
        (op.length > 2 && Util.compareBytes(op.sublist(0, 2), [255, 255]))) {
      throw Exception('Error, Reserved operator');
    }

    /// all other unknown opcodes are no-ops
    /// the cost of the no-ops is determined by the opcode number, except the
    /// 6 least significant bits.
    var costFunction = (op[op.length - 1] & 47529852928) >> 6;

    /// the multiplier cannot be 0. it starts at 1
    if (op.length > 5) {
      throw Exception('Error, Invalid operator');
    }
    var costMultiplier = Util.toInt(op.sublist(0, op.length - 1)) + 1;

    /// 0 = constant
    /// 1 = like op_add/op_sub
    /// 2 = like op_multiply
    /// 3 = like op_concat
    var cost = BigInt.zero;
    var agrsSize = 0;
    if (costFunction == 0) {
      cost = BigInt.one;
    } else if (costFunction == 1) {
      /// like op_add
      cost = Cost.ARITH_BASE_COST;
      agrsSize = 0;
      for (var length in argsLen('unknown op', args)) {
        agrsSize += length;
        cost += Cost.ARITH_COST_PER_ARG;
      }
      cost += BigInt.from(agrsSize) * Cost.ARITH_COST_PER_BYTE;
    } else if (costFunction == 2) {
      /// like op_multiply
      cost = Cost.MUL_BASE_COST;
      var operandsIterable = argsLen('unknown op', args);
      var operands = operandsIterable.iterator;
      try {
        operands.moveNext();
        var vs = operands.current;
        for (var rs in operandsIterable) {
          cost += Cost.MUL_COST_PER_OP;
          cost += (BigInt.from(rs) + BigInt.from(vs)) *
              Cost.MUL_LINEAR_COST_PER_BYTE;
          cost += (BigInt.from(rs) * BigInt.from(vs)) ~/
              Cost.MUL_SQUARE_COST_PER_BYTE_DIVIDER;

          /// this is an estimate, since we don't want to actually multiply the
          /// values
          vs += rs;
        }
      } catch (exp) {
        throw Exception('Error, $exp');
      }
    } else if (costFunction == 3) {
      /// like concat
      cost = Cost.CONCAT_BASE_COST;
      var length = 0;
      for (var arg in args.asIter()) {
        if (arg.pair != null || arg.pair.isNotEmpty) {
          throw Exception('Error, Unknown op on list');
        }
        cost += Cost.CONCAT_COST_PER_ARG;
        length += arg.atom!.length as int;
      }
      cost += BigInt.from(length) * Cost.CONCAT_COST_PER_BYTE;
    }
    cost *= BigInt.from(costMultiplier);
    if (cost >= BigInt.two.pow(32)) {
      throw Exception('Error, Invalid operator');
    }
    return Tupple.iterable2(cost, args.getNull());
  }

  static Iterable<int> argsLen(
    String opName,
    dynamic args,
  ) sync* {
    for (var arg in args.asIter()) {
      if (arg.pair != null || arg.pair.isNotEmpty) {
        throw Exception('Error, Requires int args opName: $opName, args: $arg');
      }
      yield (arg.atom!.length as int);
    }
  }

  static Map<List<int>, Function> operatorForModule(
    Map<String, List<int>> keyToAtom,
    Map<String, dynamic> keyToFunction,
    Map<String, dynamic> opNameLookup,
  ) {
    var d = <List<int>, Function>{};
    for (var op in keyToAtom.keys) {
      var opSearch = opNameLookup[op] ?? op;
      var opName = 'op_' + opSearch;
      var opF = keyToFunction[opName];
      if (opF != null) {
        d[keyToAtom[op]!] = opF;
      }
    }
    return d;
  }

  static Map<List<int>, Function> operatorForModuleSerialize(
    Map<String, List<int>> keyToAtom,
    Map<String, dynamic> keyToFunction,
    Map<String, dynamic> opNameLookup,
  ) {
    var d = <List<int>, Function>{};
    for (var op in keyToAtom.keys) {
      if (!'qa.'.contains(op)) {
        var opSearch = opNameLookup[op] ?? op;
        var opName = 'op_' + opSearch;
        var opF = keyToFunction[opName];
        if (opF != null) {
          d[keyToAtom[op]!] = opF;
        }
      }
    }
    return d;
  }

  void update(Map<List<int>, Function> data) {
    this.dict!.addAll(data);
  }

  // ignore: non_constant_identifier_names
  static final QUOTE_ATOM = KEYWORK_TO_ATOM['q'];
  static final APPLY_ATOM = KEYWORK_TO_ATOM['a'];
  static final DEFAULT_AGRS = {
    'quote': QUOTE_ATOM,
    'apply': APPLY_ATOM,
  };

  static final OPERATOR_LOOKUP = OperatorDict(
      operatorForModule(KEYWORK_TO_ATOM, CoreOps.keyToFunction, OP_REWRITE),
      [],
      DEFAULT_AGRS)
    ..update(
        operatorForModule(KEYWORK_TO_ATOM, MoreOPs.keyToFunction, OP_REWRITE));

  static final OPERATOR_LOOKUP_SERIALIZE = OperatorDict(
      operatorForModuleSerialize(
          KEYWORK_TO_ATOM, CoreOps.keyToFunction, OP_REWRITE),
      [],
      DEFAULT_AGRS)
    ..update(operatorForModuleSerialize(
        KEYWORK_TO_ATOM, MoreOPs.keyToFunction, OP_REWRITE));

  @override
  String toString() {
    return 'OperatorDict(dict: $dict, quoteAtom: $quoteAtom, applyAtom: $applyAtom, unKnownOpHandler: $unKnownOpHandler)';
  }

  Iterable<dynamic> call(List<int> op, dynamic args) {
    dynamic f;
    this.dict!.forEach((key, value) {
      if (Util.compareBytes(op, key)) {
        f = value;
      }
    });
    if (f == null) {
      return this.unKnownOpHandler!(op, args);
    } else {
      return f(args);
    }
  }

  void copyWith(
    OperatorDict other,
    Function? unKnownOpHandler,
  ) {
    this.dict = other.dict;
    this.quoteAtom = other.quoteAtom;
    this.applyAtom = other.applyAtom;
    this.unKnownOpHandler = other.unKnownOpHandler;
  }
}
