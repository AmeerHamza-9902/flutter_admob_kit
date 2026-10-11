import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Library-owned limit for concurrent fullscreen SDK load calls.
/// Each attempt holds a slot until its SDK callback or a stalled-request
/// watchdog. The owner is notified when an SDK attempt stalls.
class FullscreenRequestQueue {
  FullscreenRequestQueue({
    this.maxConcurrent = 2,
    this.stallAfter = const Duration(seconds: 20),
  }) : assert(maxConcurrent > 0),
       assert(stallAfter > Duration.zero);

  final int maxConcurrent;
  final Duration stallAfter;
  final Queue<
    ({void Function(FullscreenRequestLease) start, VoidCallback? onStalled})
  >
  _pending = Queue();
  final Set<FullscreenRequestLease> _leases = {};
  bool _draining = false;
  bool _disposed = false;

  @visibleForTesting
  int get activeCount => _leases.length;

  @visibleForTesting
  int get pendingCount => _pending.length;

  void enqueue(
    void Function(FullscreenRequestLease) start, {
    VoidCallback? onStalled,
  }) {
    if (_disposed) return;
    _pending.add((start: start, onStalled: onStalled));
    _drain();
  }

  void _drain() {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      while (_leases.length < maxConcurrent && _pending.isNotEmpty) {
        final task = _pending.removeFirst();
        final lease = FullscreenRequestLease._(this);
        _leases.add(lease);
        lease._timer = Timer(stallAfter, () {
          try {
            task.onStalled?.call();
          } finally {
            lease.release();
          }
        });
        try {
          task.start(lease);
        } catch (error) {
          lease.release();
          debugPrint('flutter_admob_kit: queued ad request failed: $error');
        }
      }
    } finally {
      _draining = false;
    }
  }

  void _release(FullscreenRequestLease lease) {
    if (!_leases.remove(lease)) return;
    lease._timer?.cancel();
    _drain();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    for (final lease in _leases) {
      lease._timer?.cancel();
    }
    _leases.clear();
  }
}

class FullscreenRequestLease {
  FullscreenRequestLease._(this._owner);

  final FullscreenRequestQueue _owner;
  Timer? _timer;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _owner._release(this);
  }
}
