import 'value_schedule.dart';
import 'audio_context.dart';
import 'connectable.dart';

class AudioParam extends Connectable with SI {
  double value; // 可以计划的值，表示偏移
  final double _min;
  final double _max;
  AudioParam(this.value, {
    double min = double.negativeInfinity,
    double max = double.infinity,
  })  : _min = min,
        _max = max;

  @override
  double get currentValue => (value + (from?.currentValue ?? 0)).clamp(_min, _max);

  final LastEffectState _lastState = LastEffectState();
  List<ValueSchedule> schedules = []; // 按照begin排序
  ValueSchedule? _lastSchedule;
  // 根据 AudioContext的currentTime 和 schedules 计算当前值
  void step() {
    double currentTime = AudioContext.instance.currentTime;
    ValueSchedule? inEffect = scheduleInEffect(currentTime);
    if (inEffect != _lastSchedule) {
      // 计划的结束/开始都要更新state
      // 如果是取消计划，保持上一个计划的初始值，也就是不更新
      if (_lastSchedule is! CancelSchedule) {
        _lastState.time = currentTime - 1 / AudioContext.instance.sampleRate;
        _lastState.value = value;
      }
      if (_lastSchedule is SetTargetSchedule) {
        // 被打断 因为endTime = infinity，所以要单独处理
        schedules.remove(_lastSchedule);
      }
      _lastSchedule = inEffect;
    }
    if (inEffect == null) return;
    value = inEffect.effect(_lastState);
    if (inEffect is CancelHoldSchedule || inEffect is CancelSchedule) {
      schedules.clear();
    } else {
      // 删除过期的计划
      for (int i = schedules.length - 1; i >= 0; i--) {
        if (schedules[i].endTime <= currentTime) {
          schedules.removeAt(i);
        }
      }
    }
  }

  /// https://webaudio.github.io/web-audio-api/#AudioParam-methods
  ValueSchedule? scheduleInEffect(double currentTime) {
    if (schedules.isEmpty) return null;
    // 还在列表中的一定是currentTime <= endTime的
    // 因此只要找startTime <= currentTime的（可以兼顾endTime==startTime的情况）
    // 后来优先
    for (int i = schedules.length - 1; i >= 0; i--) {
      if (schedules[i].startTime <= currentTime) {
        return schedules[i];
      }
    }
    return null;
  }

  AudioParam cancelAndHoldAtTime(double cancelTime) {
    schedules.add(CancelHoldSchedule(endTime: cancelTime));
    return this;
  }

  // 取消所有计划，将当前正在进行的计划清空为其开始的值
  AudioParam cancelScheduledValues(double cancelTime) {
    schedules.add(CancelSchedule(endTime: cancelTime));
    return this;
  }

  /// 从上一个 schedule 的结束时间开始，指数衰减到指定值
  AudioParam exponentialRampToValueAtTime(double value, double endTime) {
    schedules.add(ExponentialRampSchedule(target: value, endTime: endTime));
    return this;
  }

  AudioParam linearRampToValueAtTime(double value, double endTime) {
    schedules.add(LinearRampSchedule(target: value, endTime: endTime));
    return this;
  }

  AudioParam setTargetAtTime(
    double target,
    double startTime,
    double timeConstant,
  ) {
    schedules.add(
      SetTargetSchedule(
        target: target,
        startTime: startTime,
        timeConstant: timeConstant,
      ),
    );
    return this;
  }

  AudioParam setValueAtTime(double value, double startTime) {
    schedules.add(SetValueSchedule(target: value, startTime: startTime));
    return this;
  }

  AudioParam setValueCurveAtTime(
    List<double> values,
    double startTime,
    double duration,
  ) {
    schedules.add(
      ValueCurveSchedule(
        values: values,
        startTime: startTime,
        duration: duration,
      ),
    );
    return this;
  }
}
