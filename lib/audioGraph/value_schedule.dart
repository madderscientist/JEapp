import 'dart:math';

import 'audio_context.dart';

/// 对应于标准中的(T_0, V_0)
/// 在事件开始时、结束时更新
class LastEffectState {
  double time = 0;
  double value = 0;
}

// 所有事件都有起止时间
// 一般的有明确开始时间的，如 setTargetAtTime(endTime无穷大) setValueCurveAtTime
// 从现在开始的，startTime <= currentTime，如 exponentialRampToValueAtTime linearRampToValueAtTime
// 延时瞬间完成的，startTime 和 endTime 相同，如 cancelAndHoldAtTime cancelScheduledValues setValueAtTime
abstract class ValueSchedule {
  late final double target; // 目标值
  late final double startTime;
  late final double endTime;
  ValueSchedule({
    required this.target,
    this.startTime = -1,
    required this.endTime,
  });

  /// 什么时候调用依赖外界
  /// 要求：lastState.time <= currentTime <= endTime
  double effect(LastEffectState lastState);
}

/// 取消计划，保持最后的值
/// 进入此schedule时，应该更新 LastEffectState
class CancelHoldSchedule extends ValueSchedule {
  CancelHoldSchedule({required super.endTime})
    : super(startTime: endTime, target: 0);

  @override
  double effect(LastEffectState lastState) {
    return lastState.value;
  }
}

/// 和 cancelHoldAtTime 类似，取消所有计划，将当前正在进行的计划清空为其开始的值
/// 进入此schedule时，不应该更新 LastEffectState
class CancelSchedule extends ValueSchedule {
  CancelSchedule({required super.endTime})
    : super(startTime: endTime, target: 0);

  @override
  double effect(LastEffectState lastState) {
    // 取消所有计划，将当前正在进行的计划清空为其开始的值
    return lastState.value;
  }
}

/// 从当前位置开始指数衰减到目标值
class ExponentialRampSchedule extends ValueSchedule {
  ExponentialRampSchedule({required super.target, required super.endTime});

  @override
  double effect(LastEffectState lastState) {
    double currentTime = AudioContext.instance.currentTime;
    // 如果设置为0会有跳变
    if (currentTime >= endTime) return target;
    // 异号返回初始值
    if (target * lastState.value <= 0) return lastState.value;
    return lastState.value *
        pow(
          target / lastState.value,
          (currentTime - lastState.time) / (endTime - lastState.time),
        );
  }
}

/// 从当前位置开始线性衰减到目标值
class LinearRampSchedule extends ValueSchedule {
  LinearRampSchedule({required super.target, required super.endTime});

  @override
  double effect(LastEffectState lastState) {
    double currentTime = AudioContext.instance.currentTime;
    if (currentTime > endTime) return target;
    return lastState.value +
        (target - lastState.value) *
            (currentTime - lastState.time) /
            (endTime - lastState.time);
  }
}

// setTarget永远不会到目标值，理论上永远也不结束。于是标准规定到下一个事件开始时结束
class SetTargetSchedule extends ValueSchedule {
  double timeConstant;
  SetTargetSchedule({
    required super.target,
    required startTime,
    required this.timeConstant,
  }) : super(endTime: double.infinity, startTime: max(startTime, AudioContext.instance.currentTime));

  @override
  double effect(LastEffectState lastState) {
    double currentTime = AudioContext.instance.currentTime;
    return target +
        (lastState.value - target) *
            exp((lastState.time - currentTime) / timeConstant);
  }
}

class SetValueSchedule extends ValueSchedule {
  // endTime 即 startTime
  SetValueSchedule({required super.target, required super.startTime})
    : super(endTime: startTime);

  @override
  double effect(LastEffectState lastState) {
    double currentTime = AudioContext.instance.currentTime;
    if (currentTime >= endTime) return target;
    return lastState.value;
  }
}

class ValueCurveSchedule extends ValueSchedule {
  final List<double> values; // 按照时间点升序
  final double duration;
  ValueCurveSchedule({
    required this.values,
    required double startTime,
    required this.duration,
  }) : super(
         target: values.last,
         startTime: max(startTime, AudioContext.instance.currentTime),
         endTime: startTime + duration,
       );

  @override
  double effect(LastEffectState lastState) {
    double currentTime = AudioContext.instance.currentTime;
    if (currentTime >= endTime) return target;
    int k = ((values.length - 1) / duration * (currentTime - startTime))
        .floor();
    return values[k] +
        (values[k + 1] - values[k]) *
            (currentTime - startTime - k * duration / (values.length - 1)) /
            (duration / (values.length - 1));
  }
}