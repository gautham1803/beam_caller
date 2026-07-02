import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme.dart';

/// Dial pad with 6-digit input and premium call buttons.
class DialPad extends StatefulWidget {
  final Function(String number) onVoiceCall;
  final Function(String number) onVideoCall;
  final String? myNumber;

  const DialPad({
    super.key,
    required this.onVoiceCall,
    required this.onVideoCall,
    this.myNumber,
  });

  @override
  State<DialPad> createState() => _DialPadState();
}

class _DialPadState extends State<DialPad> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  bool get _isValid => _controller.text.length == 6;

  void _validateAndCall(bool isVideo) {
    final number = _controller.text.trim();

    if (number.isEmpty || number.length != 6) {
      setState(() => _error = 'Enter a 6-digit number');
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Please enter a valid 6-digit number'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(number)) {
      setState(() => _error = 'Only digits allowed');
      return;
    }

    if (number == widget.myNumber) {
      setState(() => _error = 'Cannot call yourself');
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('You cannot call your own number'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _error = null);
    HapticFeedback.mediumImpact();

    if (isVideo) {
      widget.onVideoCall(number);
    } else {
      widget.onVoiceCall(number);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary;

    return Column(
      children: [
        // Input field with premium styling
        Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppTheme.lightGray,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 10,
              color: textColor,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              filled: true,
              fillColor: cardBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 22,
              ),
              errorText: _error,
              errorStyle: const TextStyle(fontSize: 12),
              hintStyle: TextStyle(
                letterSpacing: 10,
                color: isDark ? Colors.white24 : AppTheme.offlineGray.withValues(alpha: 0.5),
              ),
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
          ),
        ),
        const SizedBox(height: 20),

        // Call buttons with enhanced styling
        Row(
          children: [
            // Voice Call
            Expanded(
              child: _PremiumCallButton(
                icon: Icons.call_rounded,
                label: 'Voice Call',
                gradient: const [Color(0xFF43A047), Color(0xFF66BB6A)],
                shadowColor: const Color(0xFF43A047),
                onPressed: () => _validateAndCall(false),
              ),
            ),
            const SizedBox(width: 14),
            // Video Call
            Expanded(
              child: _PremiumCallButton(
                icon: Icons.videocam_rounded,
                label: 'Video Call',
                gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
                shadowColor: const Color(0xFF1565C0),
                onPressed: () => _validateAndCall(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumCallButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color shadowColor;
  final VoidCallback onPressed;

  const _PremiumCallButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.shadowColor,
    required this.onPressed,
  });

  @override
  State<_PremiumCallButton> createState() => _PremiumCallButtonState();
}

class _PremiumCallButtonState extends State<_PremiumCallButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor.withValues(alpha: _isPressed ? 0.15 : 0.35),
                blurRadius: _isPressed ? 8 : 16,
                offset: Offset(0, _isPressed ? 2 : 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
