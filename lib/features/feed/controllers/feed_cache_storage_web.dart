import 'package:web/web.dart' as web;

String? getFeedCacheItem(String key) => web.window.localStorage.getItem(key);

void setFeedCacheItem(String key, String value) {
  web.window.localStorage.setItem(key, value);
}
