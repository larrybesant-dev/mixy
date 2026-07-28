import 'dart:html' as html;

String? getFeedCacheItem(String key) => html.window.localStorage[key];

void setFeedCacheItem(String key, String value) {
  html.window.localStorage[key] = value;
}
