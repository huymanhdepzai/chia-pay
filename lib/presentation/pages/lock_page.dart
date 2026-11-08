import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/app_format.dart';
import '../blocs/settings/settings_cubit.dart';

/// Màn hình khóa ứng dụng, hiển thị phủ lên toàn bộ ứng dụng khi đã đặt mã PIN.
class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  bool _error = false;

  Future<void> _onCompleted(String pin, PinPadController controller) async {
    final ok = await context.read<SettingsCubit>().unlock(pin);
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: PinPad(
          title: 'Nhập mã PIN',
          subtitle: _error ? 'Mã PIN không đúng, thử lại' : 'ChiaPay đang được khóa',
          isError: _error,
          onChanged: () {
            if (_error) setState(() => _error = false);
          },
          onCompleted: _onCompleted,
        ),
      ),
    );
  }
}

class PinPadController {
  VoidCallback? _clear;

  void clear() => _clear?.call();
}

/// Bàn phím nhập mã PIN 4 chữ số.
class PinPad extends StatefulWidget {
  static const pinLength = 4;

  final String title;
  final String subtitle;
  final bool isError;
  final VoidCallback? onChanged;
  final void Function(String pin, PinPadController controller) onCompleted;

  const PinPad({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onCompleted,
    this.isError = false,
    this.onChanged,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  final _controller = PinPadController();
  String _pin = '';

  @override
  void initState() {
    super.initState();
    _controller._clear = () => setState(() => _pin = '');
  }

  void _press(String digit) {
    if (_pin.length >= PinPad.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    widget.onChanged?.call();
    if (_pin.length == PinPad.pinLength) widget.onCompleted(_pin, _controller);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final dots = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(PinPad.pinLength, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? (widget.isError ? Colors.redAccent : primary) : Colors.transparent,
            border: Border.all(color: widget.isError ? Colors.redAccent : primary, width: 2),
          ),
        );
      }),
    );

    return Column(
      children: [
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.lock_rounded, size: 40, color: primary),
        ),
        const SizedBox(height: 24),
        Text(widget.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: 8),
        Text(widget.subtitle, style: TextStyle(color: widget.isError ? Colors.redAccent : context.textSecondary)),
        const SizedBox(height: 32),
        widget.isError ? dots.animate().shake(hz: 5, duration: 400.ms) : dots,
        const Spacer(),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                if (key.isEmpty) return const SizedBox(width: 96);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Material(
                    color: context.cardColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: key == '<' ? _backspace : () => _press(key),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: Center(
                          child: key == '<'
                              ? Icon(Icons.backspace_outlined, color: context.textPrimary)
                              : Text(key, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: context.textPrimary)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}
