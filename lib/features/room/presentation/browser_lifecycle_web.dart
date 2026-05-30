import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

html.EventListener? _unloadListener;

void registerBrowserUnloadListener(FutureOr<void> Function() onUnload) {
  _unloadListener = (html.Event event) {
    onUnload();
  };
  html.window.addEventListener('beforeunload', _unloadListener!);
}

void unregisterBrowserUnloadListener() {
  if (_unloadListener != null) {
    html.window.removeEventListener('beforeunload', _unloadListener!);
    _unloadListener = null;
  }
}






