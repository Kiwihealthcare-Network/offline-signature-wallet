class CLVMObject {
  /// """
  /// This class implements the CLVM Object protocol in the simplest possible way,
  /// by just having an "atom" and a "pair" field
  /// """
  List<int>? atom;
  Iterable<dynamic>? pair;
  // List<String> slots = ['atom', 'pair'];

  CLVMObject(dynamic v) {
    if (v is CLVMObject) {
      this.atom = v.atom;
      this.pair = v.pair;
    } else if (v is List<int>) {
      this.atom = v;
      this.pair = null;
    } else if (v is Iterable && (v is! List)) {
      if (v.length != 2) {
        throw Exception(
            'Iterable must be of size 2, cannot create CLVMObject from: $v');
      }
      this.pair = v;
      this.atom = null;
    } else {
      this.atom = v;
      this.pair = null;
    }
  }

  @override
  String toString() {
    return 'CLVMObject(atom: $atom, pair: $pair,)';
  }
}
