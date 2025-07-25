import 'package:flutter/foundation.dart';

/// 暴露notifyListeners方法的ValueNotifier
class ListNotifier<T> extends ValueNotifier<List<T>> {
  ListNotifier(super.value);
  void notify() => notifyListeners();
}

/// 可以不通知的ValueNotifier
/// 为了方便还是继承了ValueNotifier而不是重写一个
class LazyNotifier<T> extends ValueNotifier<T> {
  LazyNotifier(this._value) : super(_value);

  @override
  T get value => _value;
  T _value;
  @override
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  void setValue(T newValue) => _value = newValue;

  void notify() => notifyListeners();
}
