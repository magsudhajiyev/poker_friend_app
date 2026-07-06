import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/utils/lazy_pagination.dart';

/// U8: pure paging math for incremental list rendering.
void main() {
  group('LazyPagination', () {
    test('shownCount clamps to total and handles edges', () {
      expect(LazyPagination.shownCount(100, 15), 15);
      expect(LazyPagination.shownCount(10, 15), 10); // window bigger than data
      expect(LazyPagination.shownCount(0, 15), 0);
      expect(LazyPagination.shownCount(5, 0), 0);
      expect(LazyPagination.shownCount(5, -3), 0); // never negative
    });

    test('hasMore is true only while items remain', () {
      expect(LazyPagination.hasMore(100, 15), isTrue);
      expect(LazyPagination.hasMore(15, 15), isFalse); // exactly exhausted
      expect(LazyPagination.hasMore(10, 15), isFalse); // window exceeds data
      expect(LazyPagination.hasMore(0, 15), isFalse);
    });

    test('itemCount adds one loader row while more remain', () {
      expect(LazyPagination.itemCount(100, 15), 16); // 15 cards + loader
      expect(LazyPagination.itemCount(15, 15), 15); // no loader when done
      expect(LazyPagination.itemCount(10, 15), 10); // short list, no loader
      expect(LazyPagination.itemCount(0, 15), 0);
    });

    test('isLoaderIndex identifies exactly the trailing sentinel', () {
      // 100 items, 15 visible → indices 0..14 are cards, 15 is the loader.
      expect(LazyPagination.isLoaderIndex(15, 100, 15), isTrue);
      expect(LazyPagination.isLoaderIndex(14, 100, 15), isFalse);
      expect(LazyPagination.isLoaderIndex(0, 100, 15), isFalse);
      // Fully rendered list has no loader index.
      expect(LazyPagination.isLoaderIndex(15, 15, 15), isFalse);
    });

    test('nextVisible grows by a page and clamps to total', () {
      expect(LazyPagination.nextVisible(100, 15), 30);
      expect(LazyPagination.nextVisible(100, 90), 100); // clamp, not 105
      expect(LazyPagination.nextVisible(20, 15), 20); // clamp to short list
      expect(LazyPagination.nextVisible(100, 15, by: 50), 65);
    });

    test('paging a 47-item list reaches the end in whole pages', () {
      var visible = LazyPagination.pageSize; // 15
      final windows = <int>[visible];
      while (LazyPagination.hasMore(47, visible)) {
        visible = LazyPagination.nextVisible(47, visible);
        windows.add(visible);
      }
      expect(windows, [15, 30, 45, 47]);
      expect(LazyPagination.itemCount(47, visible), 47); // no trailing loader
    });
  });
}
