import 'dart:convert';

import 'package:safebox/clvm/program.dart';
import 'package:safebox/clvm/sexp.dart';
import 'package:safebox/util/util.dart';

class TypeReader {
  final int value;
  TypeReader(this.value);
  factory TypeReader.NULL() => TypeReader(1314212940);
  factory TypeReader.INT() => TypeReader(4804180);
  factory TypeReader.HEX() => TypeReader(4736344);
  factory TypeReader.QUOTES() => TypeReader(20820);
  factory TypeReader.DOUBLE_QUOTE() => TypeReader(4477268);
  factory TypeReader.SINGLE_QUOTE() => TypeReader(5460308);
  factory TypeReader.SYMBOL() => TypeReader(5462349);
  factory TypeReader.OPERATOR() => TypeReader(20304);
  factory TypeReader.CODE() => TypeReader(1129268293);
  factory TypeReader.NODE() => TypeReader(1313817669);
  factory TypeReader.CONS() => TypeReader(1129270867);

  bool listp() => false;

  List<int> get atom => Util.toBytes(this.value, length: length);

  int get length => (this.value.bitLength + 7) >> 3;

  @override
  String toString() => 'TypeReader(value: $value)';
}

const ASSEMBLE = """
\n(a (q #a 4 (c 2 (c 5 (c 7 0)))) (c (q (c (q . 2) (c (c (q . 1) 5) (c (a 6 (c 2 (c 11 (q 1)))) 0))) #a (i 5 (q 4 (q . 4) (c (c (q . 1) 9) (c (a 6 (c 2 (c 13 (c 11 0)))) 0))) (q . 11)) 1) 1))
    """;

class Reader {
  static int consumeWhiteSpace(
    String s,
    int offset,
  ) {
    ///"""
    ///This also deals with comments.
    ///"""
    while (true) {
      while (offset < s.length && s[offset].isSpace) {
        offset += 1;
      }
      if (offset >= s.length || s[offset] != ';') {
        break;
      }
      while (offset < s.length && !('\n\r'.contains(s[offset]))) {
        offset += 1;
      }
    }
    return offset;
  }

  static Iterable<dynamic> consumeUtilWhitespace(
    String s,
    int offset,
  ) {
    var start = offset;
    while (offset < s.length && !s[offset].isSpace && s[offset] != ')') {
      offset += 1;
    }
    return Tupple.iterable2(s.substring(start, offset), offset);
  }

  static Iterable<Iterable<dynamic>> tokenStream(String s) sync* {
    var offset = 0;
    while (offset < s.length) {
      offset = consumeWhiteSpace(s, offset);
      if (offset >= s.length) {
        break;
      }
      var c = s[offset];
      if ('(.)'.contains(c)) {
        yield Tupple.iterable2(c, offset);
        offset += 1;
        continue;
      }
      if ("\"'".contains(c)) {
        var start = offset;
        var initalC = s[start];
        offset += 1;
        while (offset < s.length && s[offset] != initalC) {
          offset += 1;
        }
        if (offset < s.length) {
          yield Tupple.iterable2(s.substring(start, offset + 1), start);
          offset += 1;
          continue;
        } else {
          throw Exception('Error, unterminated string starting at $s');
        }
      }
      var data = consumeUtilWhitespace(s, offset);
      var token = data.elementAt(0);
      var endOffset = data.elementAt(1);
      yield Tupple.iterable2(token, offset);
      offset = endOffset;
    }
  }

  static Iterable<dynamic> nextConsToken(Iterator<Iterable<dynamic>> stream) {
    late dynamic token;
    late dynamic offset;
    while (stream.moveNext()) {
      token = stream.current.elementAt(0);
      offset = stream.current.elementAt(1);
      break;
    }
    return Tupple.iterable2(token, offset);
  }

  static SExp? tokenizeInt(
    String token,
    int offset,
  ) {
    try {
      return irNew(TypeReader.INT(), int.parse(token), offset);
      // ignore: empty_catches
    } catch (exp) {}
    return null;
  }

  static SExp? tokenizeHex(
    String token,
    int offset,
  ) {
    if (token.length >= 2 && token.substring(0, 2).toUpperCase() == '0X') {
      try {
        token = token.substring(2);
        if (token.length % 2 == 1) {
          token = '0' + token;
        }
        return irNew(TypeReader.HEX(), Util.toBytes(token), offset);
      } catch (exp) {
        throw Exception('Error, invalid hex at $token');
      }
    }
    return null;
  }

  static Iterable<dynamic>? tokenizeQuotes(
    String token,
    int offset,
  ) {
    if (token.length < 2) {
      return null;
    }
    var c = token.substring(0, 1);
    if (!"'\"".contains(c)) {
      return null;
    }
    if (token[token.length - 1] != c) {
      throw Exception('Error, unterminated string starting at $token');
    }
    var qType =
        c == "'" ? TypeReader.SINGLE_QUOTE() : TypeReader.DOUBLE_QUOTE();
    return Tupple.iterable2(Tupple.iterable2(qType, offset),
        utf8.encode(token.substring(1, token.length - 1)));
  }

  static Iterable<dynamic>? tokenizeSymbol(String token, int offset) {
    return Tupple.iterable2(
        Tupple.iterable2(TypeReader.SYMBOL(), offset),
        utf8.encode(
          token,
        ));
  }

  static SExp irCons(
    dynamic firt,
    dynamic rest,
    int? offset,
  ) {
    return irNew(TypeReader.CONS(), irNew(firt, rest, null), offset);
  }

  static SExp irNew(
    dynamic type,
    dynamic val,
    int? offset,
  ) {
    if (offset != null) {
      type = SExp.to(Tupple.iterable2(type, offset));
    }
    return SExp.to(Tupple.iterable2(type, val));
  }

  static String? irAsSymbol(dynamic irSExp) {
    if (irSExp.listlp() &&
        irType(irSExp) == BigInt.from(TypeReader.SYMBOL().value)) {
      return utf8.decode(irAsSExp(irSExp).atom!);
    }
  }

  static BigInt irType(dynamic irSExp) {
    var theType = irSExp.first();
    if (theType.listlp()) {
      theType = theType.first();
    }
    return Util.toBigInt(theType.atom!);
  }

  static dynamic irAsSExp(dynamic irSExp) {
    if (irNullp(irSExp)) {
      return [];
    }
    if (irType(irSExp) == BigInt.from(TypeReader.CONS().value)) {
      return irAsSExp(irFirst(irSExp)).cons(irAsSExp(irRest(irSExp)));
    }
    return irSExp.rest();
  }

  static bool irNullp(dynamic irSExp) {
    return irType(irSExp) == BigInt.from(TypeReader.NULL().value);
  }

  static dynamic irFirst(dynamic irSExp) {
    return irSExp.rest().first();
  }

  static dynamic irRest(dynamic irSExp) {
    return irSExp.rest().rest();
  }

  static dynamic irVal(dynamic irSExp) {
    return irSExp.rest();
  }

  static dynamic irListp(dynamic irSExp) {
    return irType(irSExp) == BigInt.from(TypeReader.CONS().value);
  }

  static dynamic tokenizeSexp(
    String token,
    int offset,
    Iterator<Iterable<dynamic>> stream,
  ) {
    if (token == '(') {
      var data = nextConsToken(stream);
      token = data.elementAt(0);
      offset = data.elementAt(1);
      final result = tokenizeCons(token, offset, stream);
      return result;
    }
    for (var f in [
      tokenizeInt,
      tokenizeHex,
      tokenizeQuotes,
      tokenizeSymbol,
    ]) {
      var r = f(token, offset);
      if (r != null) {
        return r;
      }
    }
  }

  static SExp tokenizeCons(
    String token,
    int offset,
    Iterator<Iterable<dynamic>> stream,
  ) {
    if (token == ')') {
      return irNew(TypeReader.NULL(), 0, offset);
    }
    var initialOffset = offset;
    var firstSexp = tokenizeSexp(token, offset, stream);
    var data = nextConsToken(stream);
    token = data.elementAt(0);
    offset = data.elementAt(1);
    late dynamic restSexp;
    if (token == '.') {
      var dotOffset = offset;
      // grab the last item
      data = nextConsToken(stream);
      token = data.elementAt(0);
      offset = data.elementAt(1);
      restSexp = tokenizeSexp(token, offset, stream);
      data = nextConsToken(stream);
      token = data.elementAt(0);
      offset = data.elementAt(1);
      if (token != ')') {
        throw Exception('Error,illegal dot expression at $token $dotOffset');
      }
    } else {
      restSexp = tokenizeCons(token, offset, stream);
    }
    return irCons(firstSexp, restSexp, initialOffset);
  }

  static Program? readIr(String s, {Function toSexp = Program.to}) {
    var stream = tokenStream(s).iterator;
    while (stream.moveNext()) {
      return toSexp(tokenizeSexp(
          stream.current.elementAt(0), stream.current.elementAt(1), stream));
    }
  }
}

extension StringCheck on String {
// ‘ ‘ – Space
// ‘\t’ – Horizontal tab
// ‘\n’ – Newline
// ‘\v’ – Vertical tab
// ‘\f’ – Feed
// ‘\r’ – Carriage return

  bool get isSpace => " \t\n\v\f\r".contains(this);
}
