import 'package:safebox/clvm/operator.dart';
import 'package:safebox/clvm/program.dart';
import 'package:safebox/clvm/run_program.dart';
import 'package:safebox/clvm/sexp.dart';
import 'package:safebox/util/util.dart';

class SerializedProgram {
  /// """
  /// An opaque representation of a clvm program. It has a more limited interface than a full SExp
  /// """

  SerializedProgram() {
    _buf = [];
  }
  List<int> _buf = [];

  factory SerializedProgram.fromBytes(List<int> blob) {
    var ret = SerializedProgram();
    ret._buf = blob;
    return ret;
  }

  Iterable<dynamic> runWithCost(BigInt maxCost, List<dynamic> args) {
    return _run(maxCost, 0, args);
  }

  Iterable<dynamic> _run(BigInt maxCost, int flags, List<dynamic> args) {
    /// # when multiple arguments are passed, concatenate them into a serialized
    /// # buffer. Some arguments may already be in serialized form (e.g.
    /// # SerializedProgram) so we don't want to de-serialize those just to
    /// # serialize them back again. This is handled by _serialize()
    var serializedArgs = <int>[];
    if (args.length > 1) {
      /// when we have more than one argument, serialize them into a list
      for (var a in args) {
        serializedArgs += [255];
        serializedArgs += _serialize(a);
      }
      serializedArgs += [128];
    } else {
      serializedArgs += _serialize(args[0]);
    }
    //TODO: Check again
    var program = Program.fromBytes(this._buf);
    var argsNew = Program.fromBytes(serializedArgs);
    var data = RunProgram.run(
      program,
      argsNew,
      maxCost,
      OperatorDict.OPERATOR_LOOKUP_SERIALIZE,
      null,
    );
    return Tupple.iterable2(data.elementAt(0), Program.to(data.elementAt(1)));
  }

  List<int> _serialize(dynamic node) {
    if (node is SerializedProgram) {
      return node._buf;
    } else {
      return SExp.to(node).toBytes();
    }
  }

  List<int> toBytes() => this._buf;

  String toHex() => Util.toHex(this._buf);
}
