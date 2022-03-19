import 'package:safebox/clvm/operator.dart';
import 'package:safebox/core/reader.dart';

class Assemble {
  static dynamic assemble(String s) {
    var symbols = Reader.readIr(s);
    var result = assembleFromIr(symbols);
    return result;
  }

  static dynamic assembleFromIr(dynamic irSExp) {
    late List<int>? atom;
    var keyword = Reader.irAsSymbol(irSExp);
    if (keyword != null) {
      if (keyword.substring(0, 1) == '#') {
        keyword = keyword.substring(1);
      }
      atom = OperatorDict.KEYWORK_TO_ATOM[keyword];
      if (atom != null) {
        return irSExp.toIternal(atom);
      }
      if (true) {
        return Reader.irVal(irSExp);
      }
    }
    if (!Reader.irListp(irSExp)) {
      return Reader.irVal(irSExp);
    }
    if (Reader.irNullp(irSExp)) {
      return irSExp.toIternal([]);
    }
    // handle "q"
    var first = Reader.irFirst(irSExp);
    keyword = Reader.irAsSymbol(first);
    if (keyword != null && keyword == 'q') {
      // TODO: note that any symbol is legal after this point
    }
    var sexp1 = assembleFromIr(first);
    var sexp2 = assembleFromIr(Reader.irRest(irSExp));
    return sexp1.cons(sexp2);
  }
}
