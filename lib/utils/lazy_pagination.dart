/// Pure paging math for incremental ("lazy") list rendering (U8).
///
/// The full data is already in memory; this only governs how many items are
/// *built* at once so a long session/hand list doesn't construct hundreds of
/// cards up front. Kept side-effect-free so it is unit-testable without a
/// widget tree.
class LazyPagination {
  LazyPagination._();

  /// Default number of items in the first window and each subsequent page.
  static const int pageSize = 15;

  /// How close to the bottom (in items) the user must scroll before the next
  /// page is requested.
  static const int prefetchThreshold = 5;

  /// Items actually rendered: min(visible, total), never negative.
  static int shownCount(int total, int visible) {
    if (total <= 0) return 0;
    if (visible < 0) return 0;
    return visible < total ? visible : total;
  }

  /// Whether more items remain beyond the current window.
  static bool hasMore(int total, int visible) => shownCount(total, visible) < total;

  /// Row count for the ListView: shown items plus one trailing loader row
  /// while more remain.
  static int itemCount(int total, int visible) =>
      shownCount(total, visible) + (hasMore(total, visible) ? 1 : 0);

  /// True when [index] is the trailing loader sentinel (not a data row).
  static bool isLoaderIndex(int index, int total, int visible) =>
      hasMore(total, visible) && index == shownCount(total, visible);

  /// Next window size after a page request, clamped to [total]. Growing by a
  /// fixed [pageSize] keeps scrolling smooth without over-building.
  static int nextVisible(int total, int visible, {int by = pageSize}) {
    final grown = visible + by;
    return grown > total ? total : grown;
  }
}
