import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

// Web-only imports — these are only used when kIsWeb is true.
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

const String _recaptchaSiteKey = '6LcFg5UsAAAAAG8HnwVWHpKWTWHQGuSQpSbFuTaH';

@JS('grecaptcha.render')
external JSNumber _grecaptchaRender(JSString elementId, JSObject params);

@JS('grecaptcha.reset')
external void _grecaptchaReset(JSNumber widgetId);

@JS('grecaptcha')
external JSAny? get _grecaptcha;

class RecaptchaWidget extends StatefulWidget {
  final ValueChanged<String> onVerified;
  final VoidCallback? onExpired;

  const RecaptchaWidget({
    required this.onVerified,
    this.onExpired,
    super.key,
  });

  @override
  State<RecaptchaWidget> createState() => RecaptchaWidgetState();
}

class RecaptchaWidgetState extends State<RecaptchaWidget> {
  static int _counter = 0;
  late final String _viewId;
  JSNumber? _widgetId;
  bool _rendered = false;
  Timer? _renderTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _counter++;
      _viewId = 'recaptcha-container-$_counter';
      _registerView();
    }
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId, {Object? params}) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.id = _viewId;
        div.style.width = '304px';
        div.style.height = '78px';
        return div;
      },
    );

    // Poll until grecaptcha is loaded and the DOM element exists
    _renderTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_rendered) {
        timer.cancel();
        return;
      }
      _tryRender();
    });
  }

  void _tryRender() {
    if (_rendered) return;
    // Check if grecaptcha is loaded
    final grecaptchaObj = _grecaptcha;
    if (grecaptchaObj == null) return;

    // Check if the DOM element exists
    final element = web.document.getElementById(_viewId);
    if (element == null) return;

    try {
      final params = <String, Object>{
        'sitekey': _recaptchaSiteKey,
        'callback': ((JSString token) {
          widget.onVerified(token.toDart);
        }).toJS,
        'expired-callback': (() {
          widget.onExpired?.call();
        }).toJS,
      }.jsify() as JSObject;

      _widgetId = _grecaptchaRender(_viewId.toJS, params);
      _rendered = true;
    } catch (_) {
      // grecaptcha not ready yet, will retry
    }
  }

  void reset() {
    if (_widgetId != null && _rendered) {
      try {
        _grecaptchaReset(_widgetId!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 304,
      height: 78,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
