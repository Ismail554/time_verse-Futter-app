import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:time_verse/core/utils/colors.dart';

class CircularOtpField extends StatefulWidget {
  final int numberOfFields;
  final void Function(String) onSubmit;
  final TextEditingController? mainController;

  const CircularOtpField({
    super.key,
    this.numberOfFields = 6,
    required this.onSubmit,
    this.mainController,
  });

  @override
  State<CircularOtpField> createState() => _CircularOtpFieldState();
}

class _CircularOtpFieldState extends State<CircularOtpField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.numberOfFields, (_) => TextEditingController());
    _focusNodes = List.generate(widget.numberOfFields, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.numberOfFields, (index) {
        return Container(
          width: 44.w,
          height: 52.h,
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppColors.containers_bgd
                : AppColors.background_color,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: AppColors.fourth_color.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: Center(
            child: TextFormField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: GoogleFonts.outfit(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.text_color
                    : AppColors.heading_color,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                if (value.isNotEmpty && index < widget.numberOfFields - 1) {
                  _focusNodes[index + 1].requestFocus();
                }
                if (value.isEmpty && index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
                final code = _controllers.map((c) => c.text).join();
                if (widget.mainController != null) widget.mainController!.text = code;
                if (_controllers.every((c) => c.text.isNotEmpty)) {
                  widget.onSubmit(code);
                }
              },
            ),
          ),
        );
      }),
    );
  }
}
