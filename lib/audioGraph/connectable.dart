abstract class Connectable {
  double get currentValue;
  // 考虑多连接
  void beConnected(Connectable from);
  void beDisconnected(Connectable from);
  void connect(Connectable other);
  void disconnect([Connectable? other]);
}

mixin SI on Connectable {
  Connectable? from; // 连接的来源节点
  @override
  void beConnected(Connectable from) {
    if (this.from != null) {
      from.disconnect(this);
    }
    this.from = from;
  }

  @override
  void beDisconnected(Connectable from) {
    if (this.from == from) {
      this.from = null;
    }
  }

  @override
  void connect(Connectable other) {
    throw UnsupportedError('SI cannot connect to other');
  }

  @override
  void disconnect([Connectable? other]) {}
}

mixin MO on Connectable {
  List<Connectable> to = [];
  @override
  void beConnected(Connectable from) {
    throw UnsupportedError('MO cannot be connected to from');
  }
  @override
  void beDisconnected(Connectable from) {}

  @override
  void connect(Connectable other) {
    other.beConnected(this);
    to.add(other);
  }
  @override
  void disconnect([Connectable? other]) {
    if (other != null) {
      other.beDisconnected(this);
      to.remove(other);
      return;
    }
    for (var t in to) {
      t.beDisconnected(this);
    }
    to.clear();
  }
}

mixin SIMO on Connectable {
  Connectable? from; // 连接的来源节点
  List<Connectable> to = [];
  @override
  void beConnected(Connectable from) {
    if (this.from != null) {
      from.disconnect(this);
    }
    this.from = from;
  }

  @override
  void beDisconnected(Connectable from) {
    if (this.from == from) {
      this.from = null;
    }
  }

  @override
  void connect(Connectable other) {
    other.beConnected(this);
    to.add(other);
  }

  @override
  void disconnect([Connectable? other]) {
    if (other != null) {
      other.beDisconnected(this);
      to.remove(other);
      return;
    }
    for (var t in to) {
      t.beDisconnected(this);
    }
    to.clear();
  }
}

mixin MIMO on Connectable {
  List<Connectable> from = [];
  List<Connectable> to = [];
  @override
  void beConnected(Connectable from) {
    if (this.from.contains(from)) return;
    this.from.add(from);
  }

  @override
  void beDisconnected(Connectable from) {
    this.from.remove(from);
  }

  @override
  void connect(Connectable other) {
    other.beConnected(this);
    to.add(other);
  }

  @override
  void disconnect([Connectable? other]) {
    if (other != null) {
      other.beDisconnected(this);
      to.remove(other);
      return;
    }
    for (var t in to) {
      t.beDisconnected(this);
    }
    to.clear();
  }
}
