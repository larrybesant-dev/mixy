Future<void> ensureUserMediaAccess({
  required bool video,
  required bool audio,
}) async {
  // Non-web platforms do not need browser preflight.
}
