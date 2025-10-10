import 'package:flutter/foundation.dart';

/// 此类使得LazyNotifier可以代替ValueNotifier
abstract class NotifierValueListenable<T> extends ChangeNotifier
    implements ValueListenable<T> {
  @override
  T get value;
  set value(T newValue);
}

/// 暴露了notify方法的ValueNotifier
class LazyNotifier<T> extends NotifierValueListenable<T> {
  T _value;
  LazyNotifier(this._value) {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  @override
  T get value => _value;

  @override
  /// 同ValueNotifier: 改变时通知监听器
  set value(T newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  /// 直接设置值但不通知监听器
  void setValue(T newValue) => _value = newValue;

  /// 主动通知监听器
  void notify() => notifyListeners();

  @override
  String toString() => '${describeIdentity(this)}($value)';
}