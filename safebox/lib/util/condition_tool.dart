import 'package:safebox/clvm/program.dart';
import 'package:safebox/clvm/serialized_program.dart';
import 'package:safebox/clvm/sexp.dart';
import 'package:safebox/core/condition_opcode.dart';
import 'package:safebox/core/ec.dart';
import 'package:safebox/core/fields.dart';
import 'package:safebox/util/util.dart';

class ConditionTool {
  static Iterable<dynamic> conditionsDictForSolution(
    SerializedProgram puzzleReveal,
    SerializedProgram solution,
    BigInt maxCost,
  ) {
    var data = conditionForSolution(puzzleReveal, solution, maxCost);
    if (data.elementAt(0) == null) {
      return Tupple.iterable2(null, BigInt.zero);
    }
    return Tupple.iterable2(
        conditionByOpCode(data.elementAt(0)), data.elementAt(1));
  }

  /// get the standard script for a puzzle hash and feed in the solution
  static Iterable<dynamic> conditionForSolution(
    SerializedProgram puzzleReveal,
    SerializedProgram solution,
    BigInt maxCost,
  ) {
    try {
      var dataRun = puzzleReveal.runWithCost(maxCost, [solution]);
      var dataParse = parseSexpToConditions(dataRun.elementAt(1));
      return Tupple.iterable2(dataParse.elementAt(1), dataRun.elementAt(0));
    } catch (exp) {
      return Tupple.iterable2(null, BigInt.zero);
    }
  }

  ///Takes a ChiaLisp sexp (list) and returns the list of ConditionWithArgss
  ///If it fails, returns as Error
  static Iterable<dynamic> parseSexpToConditions(Program sexp) {
    var results = <ConditionWithArgs>[];
    try {
      for (var _ in sexp.asIter()) {
        var data = parseSexpToCondition(_);
        if (data.elementAt(0) != null) {
          return Tupple.iterable2(data.elementAt(0), null);
        }
        results.add(data.elementAt(1));
      }
    } catch (exp) {
      return Tupple.iterable2('Error', null);
    }
    return Tupple.iterable2(null, results);
  }

  ///Takes a ChiaLisp sexp and returns a ConditionWithArgs.
  /// If it fails, returns an Error
  static Iterable<dynamic> parseSexpToCondition(Program sexp) {
    var asAtoms = sexp.asAtomList();
    if (asAtoms.isEmpty) {
      return Tupple.iterable2('Error', null);
    }
    var opcode = asAtoms[0];
    return Tupple.iterable2(
        null, ConditionWithArgs(opcode: opcode, vars: asAtoms.sublist(1)));
  }

  ///Takes a list of ConditionWithArgss(CVP) and return dictionary of CVPs keyed of their opcode
  static Map<List<int>, List<ConditionWithArgs>> conditionByOpCode(
      List<ConditionWithArgs> conditions) {
    var d = <List<int>, List<ConditionWithArgs>>{};
    late ConditionWithArgs cvp;
    for (cvp in conditions) {
      if (d.keys.every(
          (element) => Util.toBigInt(element) != Util.toBigInt(cvp.opcode))) {
        d.addAll({cvp.opcode: []});
      }
      var _d = <List<int>, List<ConditionWithArgs>>{};
      d.forEach((key, value) {
        if (Util.toBigInt(key) == Util.toBigInt(cvp.opcode)) {
          var newValue = value..add(cvp);
          _d.addAll({key: newValue});
        } else {
          _d.addAll({key: value});
        }
      });
      d = _d;
    }
    return d;
  }

  static List<Iterable<dynamic>> pkmPairsForConditionsDict(
    Map<List<int>, List<ConditionWithArgs>> conditionsDict,
    List<int> coinName,
    List<int> additionalData,
  ) {
    var ret = <Iterable<dynamic>>[];
    var data1 = <ConditionWithArgs>[];

    conditionsDict.forEach((key, value) {
      if (Util.toBigInt(key) == Util.toBigInt(ConditionOpcode.AGG_SIG_UNSAFE)) {
        data1 = value;
      }
    });
    for (var cwa in data1) {
      //****************************************************************
      // ret.add(Tupple.iterable2(JacobianPoint.fromBytes(cwa.vars[0], Fq),
      //     cwa.vars[1] + coinName + additionalData));
      //****************************************************************
      ret.add(Tupple.iterable2(
          JacobianPoint.fromBytes(cwa.vars[0], Fq), cwa.vars[1]));
    }

    var data2 = <ConditionWithArgs>[];
    conditionsDict.forEach((key, value) {
      if (Util.toBigInt(key) == Util.toBigInt(ConditionOpcode.AGG_SIG_ME)) {
        data2 = value;
      }
    });
    for (var cwa in data2) {
      ret.add(Tupple.iterable2(JacobianPoint.fromBytes(cwa.vars[0], Fq),
          cwa.vars[1] + coinName + additionalData));
    }
    return ret;
  }
}

/// This structure is used to store parsed CLVM conditions
/// Conditions in CLVM have either format of (opcode, var1) or (opcode, var1, var2)
class ConditionWithArgs {
  List<int> opcode;
  List<List<int>> vars;
  ConditionWithArgs({
    required this.opcode,
    required this.vars,
  });
}
