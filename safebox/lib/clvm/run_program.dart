import 'package:safebox/clvm/operator.dart';
import 'package:safebox/clvm/program.dart';
import 'package:safebox/clvm/sexp.dart';
import 'package:safebox/core/costs.dart';
import 'package:safebox/util/util.dart';

class RunProgram {
  dynamic program;
  dynamic args;
  OperatorDict? operatorLookup;
  BigInt? maxCost;
  dynamic preEvalF;
  bool strict;
  dynamic preEvalOp;

  RunProgram({
    required this.program,
    required this.args,
    required this.maxCost,
    this.operatorLookup,
    this.preEvalF,
    this.strict = false,
  });

  static Iterable<dynamic> curry(
    dynamic program,
    dynamic args,
    BigInt? maxCost,
    OperatorDict? operatorLookup,
    dynamic preEvalF,
    bool strict,
  ) {
    if (strict) {
      void fatalError(String op, dynamic arguments) {
        throw Exception('Error, unimplemented operator');
      }

      operatorLookup!.unKnownOpHandler = fatalError;
    }
    return RunProgram(
      program: program,
      args: args,
      maxCost: maxCost,
      operatorLookup: operatorLookup ?? OperatorDict.OPERATOR_LOOKUP,
      preEvalF: preEvalF,
      strict: strict,
    )._runProgram();
  }

  static Iterable<dynamic> run(
    dynamic program,
    dynamic args,
    BigInt maxCost,
    dynamic operatorLookup,
    dynamic preEvalF,
  ) {
    return RunProgram(
      program: program,
      args: args,
      maxCost: maxCost,
      operatorLookup: operatorLookup ?? OperatorDict.OPERATOR_LOOKUP,
      preEvalF: preEvalF,
    )._runProgram();
  }

  Iterable<dynamic> _runProgram() {
    var program = SExp.to(this.program);
    if (this.preEvalF != null) {
      this.preEvalOp = Program.toPreEvalOp(this.preEvalF, program.toIternal);
    } else {
      this.preEvalOp = null;
    }
    var opStack = [_evalOp];
    var valueStack = [program.cons(this.args)];
    var cost = BigInt.zero;
    while (opStack.isNotEmpty) {
      var f = opStack.removeLast();
      cost += f(opStack, valueStack);
      if (this.maxCost != null &&
          this.maxCost != BigInt.zero &&
          cost > this.maxCost!) {
        throw Exception('Error, cost exceeded');
      }
    }
    return Tupple.iterable2(cost, valueStack[valueStack.length - 1]);
  }

  Iterable<dynamic> _traversePath(dynamic sexp, dynamic env) {
    var cost = Cost.PATH_LOOKUP_BASE_COST;
    cost += Cost.PATH_LOOKUP_COST_PER_LEG;
    if (sexp.nullp()) {
      return Tupple.iterable2(cost, sexp.getNull());
    }
    var b = sexp.atom;
    var endByteCursor = 0;
    while (endByteCursor < b!.length && b[endByteCursor] == 0) {
      endByteCursor += 1;
    }
    cost += BigInt.from(endByteCursor) * Cost.PATH_LOOKUP_COST_PER_ZERO_BYTE;
    if (endByteCursor == b.length) {
      return Tupple.iterable2(cost, sexp.getNull());
    }
    // create a bitmask for the most significant *set* bit
    // in the last non-zero byte
    var endBitmask = Util.msbMask(b[endByteCursor]);
    var byteCursor = b.length - 1;
    var bitmask = 1;
    while (byteCursor > endByteCursor || bitmask < endBitmask) {
      if (env.pair == null) {
        throw Exception('Error, Path into atom $env');
      }
      if (b[byteCursor] & bitmask != 0) {
        env = env.rest();
      } else {
        env = env.first();
      }
      cost += Cost.PATH_LOOKUP_COST_PER_LEG;
      bitmask <<= 1;
      if (bitmask == 256) {
        byteCursor -= 1;
        bitmask = 1;
      }
    }
    return Tupple.iterable2(cost, env);
  }

  BigInt _swapOp(List<dynamic> opStack, List<dynamic> valueStack) {
    var v2 = valueStack.removeLast();
    var v1 = valueStack.removeLast();
    valueStack.add(v2);
    valueStack.add(v1);
    return BigInt.zero;
  }

  BigInt _consOp(List<dynamic> opStack, List<dynamic> valueStack) {
    var v1 = valueStack.removeLast();
    var v2 = valueStack.removeLast();
    valueStack.add(v1.cons(v2));
    return BigInt.zero;
  }

  BigInt _evalOp(List<dynamic> opStack, List<dynamic> valueStack) {
    if (this.preEvalOp != null) {
      this.preEvalOp(opStack, valueStack);
    }
    var pair = valueStack.removeLast();
    var sexp = pair.first();
    var agrsNew = pair.rest();
    // put a bunch of ops on op_stack
    if (sexp.pair == null) {
      final data = _traversePath(sexp, agrsNew);
      final cost = data.elementAt(0);
      final r = data.elementAt(1);
      valueStack.add(r);
      return cost;
    }
    var operator = sexp.first();
    if (operator.pair != null && operator.pair!.isNotEmpty) {
      var data = operator.asPair();
      var newOperator = data!.elementAt(0);
      var mustBeNil = data.elementAt(1);
      if ((newOperator.pair != null && newOperator.pair!.isNotEmpty) ||
          (mustBeNil.atom == null || mustBeNil.atom.isNotEmpty)) {
        throw Exception('Error, in ((X)...) syntax X must be lone atom');
      }
      var newOperatorList = sexp.rest();
      valueStack.add(newOperator);
      valueStack.add(newOperatorList);
      opStack.add(_applyOp);
      return Cost.APPLY_COST;
    }
    var op = operator.atom;
    var operandList = sexp.rest();
    if (Util.compareBytes(op, this.operatorLookup!.quoteAtom!)) {
      valueStack.add(operandList);
      return Cost.QUOTE_COST;
    }
    opStack.add(_applyOp);
    valueStack.add(operator);
    while (!operandList.nullp()) {
      var _ = operandList.first();
      valueStack.add(_.cons(agrsNew));
      opStack.add(_consOp);
      opStack.add(_evalOp);
      opStack.add(_swapOp);
      operandList = operandList.rest();
    }
    valueStack.add(operator.getNull());
    return BigInt.one;
  }

  BigInt _applyOp(List<dynamic> opStack, List<dynamic> valueStack) {
    var operandList = valueStack.removeLast();
    var operator = valueStack.removeLast();
    if (operator.pair != null && operator.pair!.isNotEmpty) {
      throw Exception('Error,Internal Error $operator');
    }
    var op = operator.atom;
    if (Util.compareBytes(op, operatorLookup!.applyAtom!)) {
      if (operandList.listLen() != 2) {
        throw Exception('Error, apply requires exactly 2 parameters');
      }
      var newProgram = operandList.first();
      var newArgs = operandList.rest().first();
      valueStack.add(newProgram.cons(newArgs));
      opStack.add(_evalOp);
      return Cost.APPLY_COST;
    }
    var data = this.operatorLookup!(op, operandList);
    var additionalCost = data.elementAt(0);
    var r = data.elementAt(1);
    valueStack.add(r);
    return additionalCost as BigInt;
  }
}
