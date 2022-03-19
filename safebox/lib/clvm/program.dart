import 'package:safebox/clvm/clvm_object.dart';
import 'package:safebox/clvm/run_program.dart';
import 'package:safebox/core/assemble.dart';
import 'package:safebox/core/bytes_io.dart';
import 'package:safebox/clvm/sexp.dart';
import 'package:safebox/core/costs.dart';
import 'package:safebox/core/reader.dart';
import 'package:convert/convert.dart';

import '../util/util.dart';

class Program extends SExp {
  /// """
  /// A thin wrapper around s-expression data intended to be invoked with "eval".
  /// """
  Program(v) : super(v);

  static Program to(dynamic v) {
    if (v is Program) {
      return v;
    }
    if (SExp.lookLikeClvmObject(v)) {
      return Program(v);
    }
    return Program(SExp.toSexpType(v));
  }

  @override
  Program toIternal(dynamic v) {
    if (v is Program) {
      return v;
    }
    if (SExp.lookLikeClvmObject(v)) {
      return Program(v);
    }
    return Program(SExp.toSexpType(v));
  }

  @override
  Program first() {
    if (pair != null && pair!.isNotEmpty) {
      return Program(pair!.elementAt(0));
    } else {
      throw Exception('Error, First of non-cons');
    }
  }

  @override
  Program rest() {
    if (pair != null && pair!.isNotEmpty) {
      return Program(pair!.elementAt(1));
    } else {
      throw Exception('Error, First of non-cons');
    }
  }

  static Function toPreEvalOp(
    Function preEvalF,
    Function toSexpF,
  ) {
    dynamic myPreEvalOp(
      List<dynamic> opStack,
      List<dynamic> valueStack,
    ) {
      var v = toSexpF(valueStack[valueStack.length - 1]);
      var context = preEvalF(v.first(), v.rest());
      if (context is Function) {
        int invokeContextOp(
          List<dynamic> opStack,
          List<dynamic> valueStack,
        ) {
          context(toSexpF(valueStack[valueStack.length - 1]));
          return 0;
        }

        opStack.add(invokeContextOp);
      }
    }

    return myPreEvalOp;
  }

  static Program fromBytes(List<int> bytes) {
    final f = ByteIo(pointer: 0, bytes: bytes);
    final result = SExp.sexpFromStream(f, to);
    return result;
  }

  static Program get SYNTHETICMOD =>
      fromBytes(hex.decode('ff1dff02ffff1effff0bff02ff05808080'));

  static Program get MOD => fromBytes(hex.decode(
      'ff02ffff01ff02ffff03ff0bffff01ff02ffff03ffff09ff05ffff1dff0bffff1effff0bff0bffff02ff06ffff04ff02ffff04ff17ff8080808080808080ffff01ff02ff17ff2f80ffff01ff088080ff0180ffff01ff04ffff04ff04ffff04ff05ffff04ffff02ff06ffff04ff02ffff04ff17ff80808080ff80808080ffff02ff17ff2f808080ff0180ffff04ffff01ff32ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff06ffff04ff02ffff04ff09ff80808080ffff02ff06ffff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080'));
  static Program get MOD_SIGN => fromBytes(hex.decode('ff04ffff0101ff0280'));

  static Program get CURRYOBJCODE => Assemble.assemble(ASSEMBLE);

  @override
  Program getNull() {
    return Program(CLVMObject(<int>[]));
  }

  @override
  Program getTrue() {
    return Program(CLVMObject(<int>[1]));
  }

  @override
  Program getFalse() {
    return Program(CLVMObject(<int>[]));
  }

  @override
  String toString() {
    return 'Program(${toHex()})';
  }

  static dynamic sha256Treehash(dynamic sexp, Set? precalculated) {
    //  """
    // Hash values in `precalculated` are presumed to have been hashed already.
    // """

    dynamic handlePair(
      List<dynamic> sexpStack,
      List<dynamic> opStack,
      Set? precalculated,
    ) {
      var p0 = sexpStack.removeLast();
      var p1 = sexpStack.removeLast();
      sexpStack.add(Util.hash256([2] + p0 + p1));
    }

    dynamic roll(
      List<dynamic> sexpStack,
      List<dynamic> opStack,
      Set? precalculated,
    ) {
      var p0 = sexpStack.removeLast();
      var p1 = sexpStack.removeLast();
      sexpStack.add(p0);
      sexpStack.add(p1);
    }

    dynamic handleSexp(
      List<dynamic> sexpStack,
      List<dynamic> opStack,
      Set precalculated,
    ) {
      var sexp = sexpStack.removeLast();
      if (sexp != null && sexp.pair != null && sexp.pair!.isNotEmpty) {
        var p0 = sexp.pair.elementAt(0);
        var p1 = sexp.pair.elementAt(1);
        sexpStack.add(p0);
        sexpStack.add(p1);
        opStack.add(handlePair);
        opStack.add(handleSexp);
        opStack.add(roll);
        opStack.add(handleSexp);
      } else {
        late List<int> r;
        if (sexp != null &&
            sexp.atom != null &&
            precalculated.contains(sexp.atom)) {
          r = sexp.atom;
        } else {
          final data = sexp != null ? sexp.atom ?? <int>[] : <int>[];
          r = Util.hash256([1] + data);
        }
        sexpStack.add(r);
      }
    }

    precalculated ??= <dynamic>{};
    var sexpStack = [sexp];
    var opStack = [handleSexp];
    while (opStack.isNotEmpty) {
      var func = opStack.removeLast();
      func(sexpStack, opStack, precalculated);
    }
    return sexpStack[0];
  }

  @override
  Iterable<Program>? asPair() {
    var pairNew = this.pair;
    if (pairNew == null) {
      return null;
    }
    return Tupple.iterable2<Program>(
      Program(pairNew.elementAt(0)),
      Program(pairNew.elementAt(1)),
    );
  }

  @override
  Program cons(right) {
    return to(Tupple.iterable2(this, right));
  }

  @override
  Iterable<Program> asIter() sync* {
    var v = this;
    while (!(v.nullp())) {
      yield v.first();
      v = v.rest();
    }
  }

  ///Pretend `self` is a list of atoms. Return the corresponding
  /// python list of atoms.
  /// At each step, we always assume a node to be an atom or a pair.
  ///If the assumption is wrong, we exit early. This way we never fail
  ///and always return SOMETHING.
  List<List<int>> asAtomList() {
    var items = <List<int>>[];
    dynamic obj = this;
    while (true) {
      var pair = obj.pair;
      if (pair == null) {
        break;
      }
      var atom = pair.elementAt(0).atom;
      if (atom == null) {
        break;
      }
      items.add(atom);
      obj = pair.elementAt(1);
    }
    return items;
  }

  @override
  int listLen() {
    var v = this;
    var size = 0;
    while (v.listlp()) {
      size += 1;
      v = v.rest();
    }
    return size;
  }

  @override
  bool listlp() {
    return this.pair != null;
  }

  Iterable<dynamic> runWithCost(BigInt maxCost, dynamic args) {
    var progArgs = Program.to(args);
    var data = RunProgram.run(this, progArgs, maxCost, null, null);
    var cost = data.elementAt(0);
    var r = data.elementAt(1);
    return Tupple.iterable2(cost, Program.to(r));
  }

  Program curry(List<int> args) {
    ///"""
    ///;; A "curry" binds values to a function, making them constant,
    ///;; and returning a new function that returns fewer arguments (since the
    ///;; arguments are now fixed).
    ///;; Example: (defun add2 (V1 V2) (+ V1 V2))  ; add two values
    ///;; (curry add2 15) ; this yields a function that accepts ONE argument, and adds 15 to it

    ///`program`: an SExp
    ///`args`: an SExp that is a list of constants to be bound to `program`
    ///"""
    final argsNew = to(Tupple.iterable2(this, [args]));
    final r = RunProgram.curry(CURRYOBJCODE, argsNew, null, null, null, false);
    return r.elementAt(1);
  }

  Program run(dynamic args) {
    var r = runWithCost(Cost.INFINITE_COST, args).elementAt(1);
    return r as Program;
  }
}
