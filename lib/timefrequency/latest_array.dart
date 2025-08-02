import 'dart:typed_data';

/// 循环数组
class LatestArray {
  final Float32List _buffer;
  int _head = 0;  // 数据插入处
  int _tail = 0;

  LatestArray(int capacity) : _buffer = Float32List(capacity + 1);

  int get length => _buffer.length;

  int size() {
    int len = _head - _tail;
    if (len < 0) {
      len += length;
    }
    return len;
  }

  void push(double value) {
    _buffer[_head] = value;
    bool wasEmpty = _head == _tail;
    _head = (_head + 1) % length;
    if (_head == _tail && !wasEmpty) {
      _tail = (_tail + 1) % length;
    }
  }

  double get latest => _buffer[(length + _head - 1) % length];

  double get earliest => _buffer[_tail];

  bool get empty => _head == _tail;

  LatestArray slice(int len) {
    final result = LatestArray(len);
    final currentSize = size();
    if (len >= currentSize) {
      for (int i = 0; i < currentSize; i++) {
        result._buffer[i] = _buffer[(_tail + i) % length];
      }
      result._head = currentSize;
    } else {
      int j = _head - len;
      if (j < 0) j += length;
      for (int i = 0; i < len; i++) {
        result._buffer[i] = _buffer[(j + i) % length];
      }
      result._head = len;
    }
    result._tail = 0;
    return result;
  }

  Iterable<double> get values sync* {
    int index = _tail;
    while (index != _head) {
      yield _buffer[index];
      index = (index + 1) % length;
    }
  }
}