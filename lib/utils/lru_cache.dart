import 'dart:collection';

/// A generic Least Recently Used (LRU) cache implementation.
///
/// This cache stores key-value pairs with a maximum capacity. When the capacity
/// is exceeded, the least recently used item is automatically evicted.
class LruCache<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  /// Creates an LRU cache with the specified maximum size.
  ///
  /// The [maxSize] must be greater than 0.
  LruCache({required int maxSize}) : _maxSize = maxSize;

  /// Returns the value associated with [key], or null if not found.
  ///
  /// Accessing a value marks it as recently used.
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      return null;
    }

    // Move to end (mark as recently used).
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
    }
    return value;
  }

  /// Associates [key] with [value] in the cache.
  ///
  /// If the cache exceeds [maxSize], the least recently used entry is removed.
  void put(K key, V value) {
    // Remove existing key to update its position.
    _cache.remove(key);

    // Evict least recently used if at capacity.
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = value;
  }

  void remove(K key) {
    _cache.remove(key);
  }

  /// Returns whether [key] exists in the cache.
  bool containsKey(K key) => _cache.containsKey(key);

  /// Removes all entries from the cache.
  void clear() => _cache.clear();

  /// Returns the current number of entries in the cache.
  int get length => _cache.length;

  /// Returns the maximum size of the cache.
  int get maxSize => _maxSize;
}
