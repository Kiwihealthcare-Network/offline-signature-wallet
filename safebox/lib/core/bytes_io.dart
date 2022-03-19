class ByteIo {
  int pointer;
  List<int> bytes;
  ByteIo({
    required this.pointer,
    required this.bytes,
  });

  List<int> read(int index) {
    if (pointer > bytes.length) {
      return <int>[];
    }
    var len = index + pointer;
    if (len > bytes.length) {
      len = bytes.length;
    }
    final data = bytes.sublist(pointer, len);
    pointer += index;
    return data;
  }

  void write(List<int> data) {
    this.bytes += data;
    this.pointer += data.length;
  }

  @override
  String toString() => 'ByteIo(pointer: $pointer, bytes: $bytes)';
}
