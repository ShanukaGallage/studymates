import 'package:material_ui/material_ui.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
  });
  final int minLines, maxLines;
  final int? maxLength;
  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    minLines: widget.minLines,
    maxLines: widget.maxLines,
    maxLength: widget.maxLength,
    validator: widget.validator,
    onChanged: widget.onChanged,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    obscureText: widget.isPassword && !_showPassword,
    autocorrect: !widget.isPassword,
    enableSuggestions: !widget.isPassword,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: widget.isPassword
          ? IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
            )
          : null,
    ),
  );
}
