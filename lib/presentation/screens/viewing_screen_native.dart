// Native platform fullscreen - no-op since SystemChrome is used directly
// This file exists for conditional import to work

/// Toggle fullscreen mode - no-op for native platforms
/// Actual implementation uses SystemChrome in viewing_screen.dart
void toggleFullscreen(bool enterFullscreen) {
  // No-op: Native platforms use SystemChrome directly in the main file
}

/// Check if currently in fullscreen mode - always returns false for native
bool isFullscreen() {
  return false;
}
