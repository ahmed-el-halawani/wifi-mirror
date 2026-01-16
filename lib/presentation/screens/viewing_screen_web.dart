// Web-specific fullscreen implementation using dart:html
import 'dart:html' as html;
import 'dart:js' as js;

/// Toggle fullscreen mode for web browser
void toggleFullscreen(bool enterFullscreen) {
  try {
    if (enterFullscreen) {
      // Request fullscreen on document element
      final element = html.document.documentElement;
      if (element != null) {
        // Try different browser-specific methods
        js.context.callMethod('eval', [
          '''
          (function() {
            var elem = document.documentElement;
            if (elem.requestFullscreen) {
              elem.requestFullscreen();
            } else if (elem.webkitRequestFullscreen) {
              elem.webkitRequestFullscreen();
            } else if (elem.mozRequestFullScreen) {
              elem.mozRequestFullScreen();
            } else if (elem.msRequestFullscreen) {
              elem.msRequestFullscreen();
            }
          })();
          ''',
        ]);
      }
    } else {
      // Exit fullscreen
      js.context.callMethod('eval', [
        '''
        (function() {
          if (document.exitFullscreen) {
            document.exitFullscreen();
          } else if (document.webkitExitFullscreen) {
            document.webkitExitFullscreen();
          } else if (document.mozCancelFullScreen) {
            document.mozCancelFullScreen();
          } else if (document.msExitFullscreen) {
            document.msExitFullscreen();
          }
        })();
        ''',
      ]);
    }
  } catch (e) {
    // Ignore errors - fullscreen may not be supported
    print('Fullscreen error: $e');
  }
}

/// Check if currently in fullscreen mode
bool isFullscreen() {
  try {
    return html.document.fullscreenElement != null;
  } catch (e) {
    return false;
  }
}
