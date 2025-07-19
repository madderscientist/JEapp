import 'package:flutter/cupertino.dart';

/// 暴露notifyListeners方法的ValueNotifier
class ListNotifier<T> extends ValueNotifier<List<T>>{
  ListNotifier(super.value);
  void notify() => notifyListeners();
}