final Map<String, String> _memoryStorage = <String, String>{};

String? getFeedCacheItem(String key) => _memoryStorage[key];

void setFeedCacheItem(String key, String value) {
  _memoryStorage[key] = value;
}
