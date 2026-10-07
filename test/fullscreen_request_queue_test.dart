import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/src/fullscreen_request_queue.dart';

void main() {
  test('limits concurrent requests and drains in FIFO order', () {
    final queue = FullscreenRequestQueue();
    final started = <int>[];
    final leases = <FullscreenRequestLease>[];
    for (var index = 1; index <= 3; index++) {
      queue.enqueue((lease) {
        started.add(index);
        leases.add(lease);
      });
    }
    expect(started, [1, 2]);
    expect(queue.activeCount, 2);
    expect(queue.pendingCount, 1);
    leases.first.release();
    expect(started, [1, 2, 3]);
    expect(queue.activeCount, 2);
    leases.first.release();
    expect(queue.activeCount, 2);
    queue.dispose();
  });

  testWidgets('stalled SDK callback cannot starve every later placement', (
    tester,
  ) async {
    final queue = FullscreenRequestQueue(
      maxConcurrent: 1,
      stallAfter: const Duration(milliseconds: 20),
    );
    final started = <int>[];
    queue.enqueue((_) => started.add(1));
    queue.enqueue((_) => started.add(2));
    expect(started, [1]);
    await tester.pump(const Duration(milliseconds: 21));
    expect(started, [1, 2]);
    queue.dispose();
  });
}
