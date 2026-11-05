import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/pin_gate.dart';

const _pinLength = 4;

/// Asks for the PIN, or Face ID / a fingerprint, before a change that loosens
/// the rules. Pops `true` once the user is let through.
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key, required this.reason});

  /// What the PIN is for, e.g. "Хязгаарыг сулруулахын тулд".
  final String reason;

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  /// Wrong tries in a row before the pad rests for [_pause].
  static const _triesBeforePause = 5;
  static const _pause = Duration(seconds: 30);

  String _code = '';
  String? _error;
  int _wrong = 0;
  int _shakes = 0;
  bool _biometrics = false;
  Timer? _resting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBiometrics());
  }

  @override
  void dispose() {
    _resting?.cancel();
    super.dispose();
  }

  Future<void> _startBiometrics() async {
    if (!await ref.read(biometricsProvider).available() || !mounted) return;
    setState(() => _biometrics = true);
    await _useBiometrics();
  }

  Future<void> _useBiometrics() async {
    if (await ref.read(biometricsProvider).authenticate(widget.reason) && mounted) Navigator.pop(context, true);
  }

  void _digit(String digit) {
    if (_resting != null || _code.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _code += digit;
      _error = null;
    });
    if (_code.length == _pinLength) _check();
  }

  void _check() {
    if (ref.read(pinStoreProvider).verify(_code)) {
      Navigator.pop(context, true);
      return;
    }
    HapticFeedback.heavyImpact();
    _wrong++;
    final rest = _wrong % _triesBeforePause == 0;
    setState(() {
      _code = '';
      _shakes++;
      _error = rest ? '${_pause.inSeconds} секундын дараа дахин оролдоно уу' : 'PIN буруу байна';
    });
    if (rest) {
      _resting = Timer(_pause, () {
        if (mounted) {
          setState(() {
            _resting = null;
            _error = null;
          });
        }
      });
    }
  }

  /// The phone's own lock lets the owner set a new PIN.
  Future<void> _forgot() async {
    final ok = await ref.read(biometricsProvider).authenticateDevice('PIN кодоо шинэчлэхийн тулд утасныхаа түгжээг тайлна уу');
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Утасны түгжээгээр баталгаажуулж чадсангүй');
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PinSetupScreen()),
    );
    if (created == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _PinLayout(
      title: 'PIN код оруулна уу',
      message: _error ?? widget.reason,
      isError: _error != null,
      entered: _code.length,
      shakes: _shakes,
      enabled: _resting == null,
      onDigit: _digit,
      onDelete: () => setState(() => _code = _code.isEmpty ? '' : _code.substring(0, _code.length - 1)),
      onCancel: () => Navigator.pop(context, false),
      leftKey: _biometrics
          ? _KeyButton.icon(icon: Icons.fingerprint_rounded, tooltip: 'Хурууны хээ эсвэл Face ID', onPressed: _useBiometrics)
          : null,
      footer: TextButton(
        onPressed: _forgot,
        style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: AppColors.muted),
        child: const Text('PIN кодоо мартсан уу?'),
      ),
    );
  }
}

/// Creates a PIN: entered twice, then saved. Pops `true` once saved.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _code = '';
  String? _first;
  bool _mismatch = false;
  int _shakes = 0;

  Future<void> _digit(String digit) async {
    if (_code.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _code += digit;
      _mismatch = false;
    });
    if (_code.length < _pinLength) return;

    final first = _first;
    if (first == null) {
      setState(() {
        _first = _code;
        _code = '';
      });
    } else if (first == _code) {
      await ref.read(pinStoreProvider).setPin(_code);
      if (mounted) Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _first = null;
        _code = '';
        _mismatch = true;
        _shakes++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return _PinLayout(
      title: confirming ? 'PIN-ээ дахин оруулна уу' : 'Шинэ PIN код үүсгэх',
      message: _mismatch
          ? 'Хоёр код таарсангүй. Дахин эхэлнэ үү.'
          : 'Хаалт унтраах, хязгаар нэмэхэд энэ кодыг асууна',
      isError: _mismatch,
      entered: _code.length,
      shakes: _shakes,
      enabled: true,
      onDigit: _digit,
      onDelete: () => setState(() => _code = _code.isEmpty ? '' : _code.substring(0, _code.length - 1)),
      onCancel: () => Navigator.pop(context, false),
    );
  }
}

/// The PIN artboard: lock, title, message, four dots, keypad.
class _PinLayout extends StatelessWidget {
  const _PinLayout({
    required this.title,
    required this.message,
    required this.isError,
    required this.entered,
    required this.shakes,
    required this.enabled,
    required this.onDigit,
    required this.onDelete,
    required this.onCancel,
    this.leftKey,
    this.footer,
  });

  final String title;
  final String message;
  final bool isError;
  final int entered;

  /// Bumped on each wrong code to shake the dots.
  final int shakes;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  /// Bottom-left of the keypad, empty in the design; holds Face ID / fingerprint.
  final Widget? leftKey;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final header = Column(
      spacing: 14,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
          child: SizedBox.square(dimension: 64, child: Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28)),
        ),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: AppText.screenTitle.copyWith(fontSize: 22))),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: isError ? AppColors.warmText : AppColors.muted),
          ),
        ),
        const SizedBox(height: 0),
        TweenAnimationBuilder<double>(
          key: ValueKey(shakes),
          tween: Tween(begin: shakes == 0 || still ? 0 : 1, end: 0),
          duration: const Duration(milliseconds: 420),
          builder: (context, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * 12 * t, 0), child: child),
          child: Semantics(
            label: '$_pinLength оронтой кодоос $entered орон оруулсан',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [for (var i = 0; i < _pinLength; i++) _Dot(filled: i < entered)],
            ),
          ),
        ),
      ],
    );

    final keypad = Column(
      spacing: 16,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _KeyRow(children: [for (final d in row) _KeyButton.digit(d, enabled ? () => onDigit(d) : null)]),
        _KeyRow(
          children: [
            leftKey ?? const SizedBox.square(dimension: _KeyButton.size),
            _KeyButton.digit('0', enabled ? () => onDigit('0') : null),
            _KeyButton.icon(icon: Icons.backspace_outlined, tooltip: 'Устгах', onPressed: entered == 0 ? null : onDelete),
          ],
        ),
        ?footer,
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.chevron_left_rounded, size: 22),
                          label: const Text('Буцах'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.ink, minimumSize: const Size(0, 44)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: header),
                      const Spacer(),
                      const SizedBox(height: 32),
                      keypad,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.ink : Colors.transparent,
        border: Border.all(color: filled ? AppColors.ink : AppColors.inactive, width: 2),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, spacing: 28, children: children);
}

class _KeyButton extends StatelessWidget {
  const _KeyButton.digit(String this.digit, this.onPressed)
      : icon = null,
        tooltip = null;

  const _KeyButton.icon({required IconData this.icon, required String this.tooltip, required this.onPressed}) : digit = null;

  static const double size = 76;

  final String? digit;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final digit = this.digit;
    if (digit == null) {
      return SizedBox.square(
        dimension: size,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, size: 26),
          color: AppColors.ink,
          disabledColor: AppColors.idleBar,
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(child: Text(digit, style: AppText.numeric(24, color: onPressed == null ? AppColors.idleBar : AppColors.ink))),
        ),
      ),
    );
  }
}
