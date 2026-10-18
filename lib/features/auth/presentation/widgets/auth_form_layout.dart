import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import 'auth_brand_header.dart';

class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.formTitle,
    this.formSubtitle,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final String? formTitle;
  final String? formSubtitle;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            ColoredBox(
              color: const Color(0xFF104C3B),
              child: SizedBox(
                height: MediaQuery.paddingOf(context).top,
                width: double.infinity,
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: LayoutBuilder(
                      builder: (context, viewport) => SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: viewport.maxHeight,
                          ),
                          child: ColoredBox(
                            color: const Color(0xFFF8FAF8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ColoredBox(
                                  color: const Color(0xFF104C3B),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AuthBrandHeader(
                                        title: title,
                                        subtitle: subtitle,
                                        onBack: onBack,
                                        compact: compact,
                                      ),
                                      Container(
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF8FAF8),
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(32),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    viewport.maxWidth < 360 ? 20 : 28,
                                    4,
                                    viewport.maxWidth < 360 ? 20 : 28,
                                    28,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (formTitle != null) ...[
                                        Text(
                                          formTitle!,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            color: Color(0xFF173C2D),
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -.5,
                                          ),
                                        ),
                                        if (formSubtitle != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            formSubtitle!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF60756B),
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 26),
                                      ],
                                      child,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration authInputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
  String? helperText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF718079), fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF567567), size: 19),
    suffixIcon: suffixIcon,
    helperText: helperText,
    helperMaxLines: 3,
    errorMaxLines: 3,
    constraints: const BoxConstraints(minHeight: 56),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(const Color(0xFFDCE5DE)),
    enabledBorder: border(const Color(0xFFDCE5DE)),
    disabledBorder: border(const Color(0xFFE7EDE8)),
    focusedBorder: border(AppColors.primary, 1.5),
    errorBorder: border(const Color(0xFFB33D3D)),
    focusedErrorBorder: border(const Color(0xFFB33D3D), 1.5),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({required this.label, required this.child, super.key});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class AuthSectionTitle extends StatelessWidget {
  const AuthSectionTitle({required this.title, this.subtitle, super.key});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60756B),
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
    super.key,
  });
  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFDDE8E1),
        disabledForegroundColor: AppColors.primaryDark,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              isLoading ? loadingLabel : label,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}

class AuthNavigationPrompt extends StatelessWidget {
  const AuthNavigationPrompt({
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });
  final String prompt;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 2,
    children: [
      Text(
        prompt,
        style: const TextStyle(color: Color(0xFF5C7064), fontSize: 13),
      ),
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(actionLabel),
      ),
    ],
  );
}
