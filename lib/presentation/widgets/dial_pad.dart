import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme.dart';

/// Dial pad with 6-digit input and call buttons.
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

    if (number.length != 6) {
      setState(() => _error = 'Enter a 6-digit number');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(number)) {
      setState(() => _error = 'Only digits allowed');
      return;
    }

    if (number == widget.myNumber) {
      setState(() => _error = 'Cannot call yourself');
      return;
    }

    setState(() => _error = null);

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
    return Column(
      children: [
        // Input field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppTheme.primaryBlue,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              errorText: _error,
              errorStyle: const TextStyle(fontSize: 12),
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
          ),
        ),
        const SizedBox(height: 24),

        // Call buttons
        Row(
          children: [
            // Voice Call
            Expanded(
              child: _CallButton(
                icon: Icons.call_rounded,
                label: 'Voice Call',
                color: AppTheme.activeGreen,
                onPressed: _isValid ? () => _validateAndCall(false) : null,
              ),
            ),
            const SizedBox(width: 16),
            // Video Call
            Expanded(
              child: _CallButton(
                icon: Icons.videocam_rounded,
                label: 'Video Call',
                color: AppTheme.primaryBlue,
                onPressed: _isValid ? () => _validateAndCall(true) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              color: isEnabled ? null : AppTheme.lightGray,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isEnabled ? Colors.white : AppTheme.offlineGray,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: isEnabled ? Colors.white : AppTheme.offlineGray,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
