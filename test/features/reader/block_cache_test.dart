import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/features/reader/data/block_cache.dart';

void main() {
  test('put/get round-trip', () {
    final c = BlockCache();
    c.put(2, ['<p>a</p>']);
    expect(c.get(2), ['<p>a</p>']);
    expect(c.contains(2), true);
  });

  test('evictFar drops chapters outside the keepAround window', () {
    final c = BlockCache(keepAround: 1);
    for (var i = 0; i < 10; i++) {
      c.put(i, ['#$i']);
    }
    final evicted = c.evictFar(5);
    expect(evicted.toSet(), {0, 1, 2, 3, 7, 8, 9});
    expect(c.indices.toSet(), {4, 5, 6});
  });

  test('keepAround=2 retains a wider window', () {
    final c = BlockCache(keepAround: 2);
    for (var i = 0; i < 10; i++) {
      c.put(i, ['#$i']);
    }
    c.evictFar(5);
    expect(c.indices.toSet(), {3, 4, 5, 6, 7});
  });

  test('evictFar is a no-op when nothing is far', () {
    final c = BlockCache(keepAround: 1);
    c.put(3, ['x']);
    c.put(4, ['y']);
    expect(c.evictFar(3), isEmpty);
    expect(c.size, 2);
  });
}
