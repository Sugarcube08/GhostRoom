import 'dart:collection';

class LRUMemoryCache<K, V> {
  final int maximumSizeBytes;
  final int Function(K key, V value) sizeEstimator;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();
  int _currentSizeBytes = 0;

  LRUMemoryCache({
    required this.maximumSizeBytes,
    required this.sizeEstimator,
  });

  int get currentSizeBytes => _currentSizeBytes;
  int get length => _cache.length;

  V? get(K key) {
    if (_cache.containsKey(key)) {
      final value = _cache.remove(key) as V;
      _cache[key] = value; // Move to end (most recently used)
      return value;
    }
    return null;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      final oldValue = _cache.remove(key) as V;
      _currentSizeBytes -= sizeEstimator(key, oldValue);
    }

    _cache[key] = value;
    _currentSizeBytes += sizeEstimator(key, value);

    _evictIfNeeded();
  }

  V? remove(K key) {
    if (_cache.containsKey(key)) {
      final value = _cache.remove(key) as V;
      _currentSizeBytes -= sizeEstimator(key, value);
      return value;
    }
    return null;
  }

  void _evictIfNeeded() {
    while (_currentSizeBytes > maximumSizeBytes && _cache.isNotEmpty) {
      final firstKey = _cache.keys.first;
      final firstValue = _cache.remove(firstKey) as V;
      _currentSizeBytes -= sizeEstimator(firstKey, firstValue);
    }
  }

  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
  }

  bool containsKey(K key) => _cache.containsKey(key);

  Iterable<K> get keys => _cache.keys;
  Iterable<V> get values => _cache.values;
}
