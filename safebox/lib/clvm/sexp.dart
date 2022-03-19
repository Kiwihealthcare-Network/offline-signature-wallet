import 'dart:convert';

import 'package:safebox/core/bytes_io.dart';
import 'package:safebox/clvm/clvm_object.dart';
import 'package:safebox/core/reader.dart';
import 'package:safebox/util/util.dart';
import 'package:safebox/core/ec.dart';

import 'program.dart';

class SExp {
  ///   """
  /// SExp provides higher level API on top of any object implementing the CLVM
  /// object protocol.
  /// The tree of values is not a tree of SExp objects, it's a tree of CLVMObject
  /// like objects. SExp simply wraps them to privide a uniform view of any
  /// underlying conforming tree structure.

  /// The CLVM object protocol (concept) exposes two attributes:
  /// 1. "atom" which is either None or bytes
  /// 2. "pair" which is either None or a tuple of exactly two elements. Both
  ///   elements implementing the CLVM object protocol.
  /// Exactly one of "atom" and "pair" must be None.
  /// """
  List<int>? atom;
  Iterable<dynamic>? pair;

  SExp(dynamic v) {
    this.atom = v.atom;
    this.pair = v.pair;
  }

  static SExp to(dynamic v) {
    if (v is SExp) {
      return v;
    }
    if (lookLikeClvmObject(v)) {
      return SExp(v);
    }
    return SExp(toSexpType(v));
  }

  SExp toIternal(dynamic v) {
    if (v is SExp) {
      return v;
    }
    if (lookLikeClvmObject(v)) {
      return SExp(v);
    }
    return SExp(toSexpType(v));
  }

  static void opReadSexp(
    List<dynamic> opStack,
    List<dynamic> valStack,
    ByteIo f,
  ) {
    final blob = f.read(1);
    if (blob.isEmpty) {
      throw Exception('Error, Bad encoding');
    }
    var b = blob[0];
    if (b == 255) {
      opStack.add(opCons);
      opStack.add(opReadSexp);
      opStack.add(opReadSexp);
      return;
    }
    valStack.add(atomFromStream(
      f,
      b,
    ));
  }

  SExp getNull() {
    return SExp(CLVMObject(<int>[]));
  }

  SExp getTrue() {
    return SExp(CLVMObject(<int>[1]));
  }

  SExp getFalse() {
    return SExp(CLVMObject(<int>[]));
  }

  static void opCons(
    List<dynamic> opStack,
    List<dynamic> valStack,
    ByteIo f,
  ) {
    var right = valStack.removeLast();
    var left = valStack.removeLast();
    valStack.add(CLVMObject(Tupple.iterable2(left, right)));
  }

  static CLVMObject atomFromStream(
    ByteIo f,
    int b,
  ) {
    if (b == 128) {
      return CLVMObject(<int>[]);
    }
    if (b <= 127) {
      return CLVMObject([b]);
    }
    var bitCount = 0;
    var bitMask = 128;
    while (b & bitMask != 0) {
      bitCount += 1;
      b &= 255 ^ bitMask;
      bitMask >>= 1;
    }
    var sizeBlob = Util.toBytes(b);
    if (bitCount > 1) {
      final bytes = f.read(bitCount - 1);
      if (bytes.length != bitCount - 1) {
        throw Exception('Error, Bad encoding');
      }
      sizeBlob += bytes;
    }
    final size = Util.toInt(sizeBlob);
    if (size >= 17179869184) {
      throw Exception('Error, Blob too large');
    }
    final blob = f.read(size);
    if (blob.length != size) {
      throw Exception('Error, Bad encoding');
    }
    return CLVMObject(blob);
  }

  static dynamic sexpFromStream(ByteIo f, Function toSexp) {
    var opStack = <dynamic>[opReadSexp];
    var valStack = <dynamic>[];
    late dynamic func;
    while (opStack.isNotEmpty) {
      func = opStack.removeLast();
      func(opStack, valStack, f);
    }
    return toSexp(valStack.removeLast());
  }

  static dynamic toSexpType(dynamic v) {
    var stack = [v];
    var ops = <Iterable>[Tupple.iterable2(BigInt.zero, null)];
    late dynamic op;
    late dynamic target;
    late dynamic left;
    late dynamic right;
    late dynamic vNew;
    while (ops.isNotEmpty) {
      final opRemove = ops.removeLast();
      op = opRemove.elementAt(0);
      target = opRemove.elementAt(1);
      if (op == BigInt.zero) {
        if (lookLikeClvmObject(stack[stack.length - 1])) {
          continue;
        }
        vNew = stack.removeLast();
        if (vNew is List && (vNew is! List<int>)) {
          target = stack.length;
          stack.add(CLVMObject(<int>[]));
          for (var _ in vNew) {
            stack.add(_);
            ops.add(Tupple.iterable2(BigInt.from(3), target));
            if (!lookLikeClvmObject(_)) {
              ops.add(Tupple.iterable2(BigInt.zero, null));
            }
          }
          continue;
        }
        if (vNew is Iterable && (vNew is! List)) {
          if (vNew.length != 2) {
            throw Exception("Error,can't cast List of size ${vNew.length}");
          }
          left = vNew.elementAt(0);
          right = vNew.elementAt(1);
          target = stack.length;

          stack.add(CLVMObject(Tupple.iterable2(left, right)));
          if (!lookLikeClvmObject(right)) {
            stack.add(right);
            ops.add(Tupple.iterable2(BigInt.two, target));
            ops.add(Tupple.iterable2(BigInt.zero, null));
          }
          if (!lookLikeClvmObject(left)) {
            stack.add(left);
            ops.add(Tupple.iterable2(BigInt.one, target));
            ops.add(Tupple.iterable2(BigInt.zero, null));
          }
          continue;
        }
        stack.add(CLVMObject(convertAtomToBytes(vNew)));
        continue;
      }
      if (op == BigInt.one) {
        stack[target].pair = Tupple.iterable2(
            CLVMObject(stack.removeLast()), stack[target].pair.elementAt(1));
        continue;
      }
      if (op == BigInt.two) {
        stack[target].pair = Tupple.iterable2(
            stack[target].pair.elementAt(0), CLVMObject(stack.removeLast()));
        continue;
      }
      if (op == BigInt.from(3)) {
        stack[target] =
            CLVMObject(Tupple.iterable2(stack.removeLast(), stack[target]));
        continue;
      }
    }
    if (stack.length != 1) {
      throw Exception('Error, Internal error');
    }
    return stack[0];
  }

  static List<int> convertAtomToBytes(dynamic data) {
    if (data is List<int>) {
      return data;
    }
    if (data is String) {
      return utf8.encode(data);
    }
    if (data is BigInt) {
      return Util.intToByte(data);
    }
    if (data is int) {
      return Util.intToByte(data);
    }
    if (data is JacobianPoint) {
      return data.toBytes();
    }
    if (data == null) {
      return [];
    }
    if (data is List && data.isEmpty) {
      return [];
    }
    if (data is TypeReader) {
      return Util.toBytes(data.value);
    }
    throw Exception("Error, Can't cast ${data.runtimeType} to bytes");
  }

  static bool lookLikeClvmObject(dynamic data) =>
      data is CLVMObject || data is SExp || data is Program;

  SExp first() {
    if (pair != null && pair!.isNotEmpty) {
      return SExp(pair!.elementAt(0));
    } else {
      throw Exception('Error, First of non-cons');
    }
  }

  SExp rest() {
    if (pair != null && pair!.isNotEmpty) {
      return SExp(pair!.elementAt(1));
    } else {
      throw Exception('Error, First of non-cons');
    }
  }

  bool nullp() {
    final v = atom;
    return v != null && v.isEmpty;
  }

  SExp cons(right) {
    return to(Tupple.iterable2(this, right));
  }

  Iterable<SExp>? asPair() {
    var pairNew = this.pair;
    if (pairNew == null) {
      return null;
    }
    return Tupple.iterable2<SExp>(
      SExp(pairNew.elementAt(0)),
      SExp(pairNew.elementAt(1)),
    );
  }

  Iterable<SExp> asIter() sync* {
    var v = this;
    while (!(v.nullp())) {
      yield v.first();
      v = v.rest();
    }
  }

  int listLen() {
    var v = this;
    var size = 0;
    while (v.listlp()) {
      size += 1;
      v = v.rest();
    }
    return size;
  }

  bool listlp() {
    return this.pair != null;
  }

  BigInt asBigInt() {
    return Util.toBigInt(atom!, signed: true);
  }

  List<int> toBytes() {
    var f = ByteIo(pointer: 0, bytes: []);
    sexpToStream(f);
    return f.bytes;
  }

  String toHex() {
    return Util.toHex(toBytes());
  }

  void sexpToStream(ByteIo f) {
    for (var b in sexpToByteIterator()) {
      f.write(b);
    }
  }

  Iterable<List<int>> sexpToByteIterator() sync* {
    var todoStack = [this];
    late dynamic sexpNew;
    late Iterable<dynamic>? pair;
    while (todoStack.isNotEmpty) {
      sexpNew = todoStack.removeLast();
      pair = sexpNew.asPair();
      if (pair != null && pair.isNotEmpty) {
        yield [255];
        todoStack.add(pair.elementAt(1));
        todoStack.add(pair.elementAt(0));
      } else {
        yield* atomToBytesIterator(sexpNew.atom);
      }
    }
  }

  Iterable<List<int>> atomToBytesIterator(List<int>? atom) sync* {
    if (atom == null) {
      return;
    }
    var size = atom.length;
    if (size == 0) {
      yield [128];
      return;
    }
    if (size == 1) {
      if (atom[0] <= 127) {
        yield atom;
        return;
      }
    }
    late List<int> sizeBlob;
    if (size < 64) {
      sizeBlob = Util.toBytes(128 | size);
    } else if (size < 8192) {
      sizeBlob =
          Util.toBytes(192 | (size >> 8)) + Util.toBytes((size >> 0) & 255);
    } else if (size < 1048576) {
      sizeBlob = Util.toBytes(224 | (size >> 16)) +
          Util.toBytes((size >> 8) & 255) +
          Util.toBytes((size >> 0) & 255);
    } else if (size < 134217728) {
      sizeBlob = Util.toBytes(240 | (size >> 24)) +
          Util.toBytes((size >> 16) & 255) +
          Util.toBytes((size >> 8) & 255) +
          Util.toBytes((size >> 0) & 255);
    } else if (size < 17179869184) {
      sizeBlob = Util.toBytes(248 | (size >> 32)) +
          Util.toBytes((size >> 24) & 255) +
          Util.toBytes((size >> 16) & 255) +
          Util.toBytes((size >> 8) & 255) +
          Util.toBytes((size >> 0) & 255);
    } else {
      throw Exception('Error, sexp too long');
    }
    yield sizeBlob;
    yield atom;
  }

  @override
  String toString() => 'SExp(${toHex()})';
}

extension Tupple on Iterable {
  static Iterable<E> iterable2<E>(E value1, E value2) =>
      Iterable<E>.generate(2, (index) => index == 0 ? value1 : value2);
}
