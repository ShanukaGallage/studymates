import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

Future<String?> showPreviewGoalSheet(
  BuildContext context,
  String initialGoal, {
  bool preview = true,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _GoalSheet(initialGoal: initialGoal, preview: preview),
);

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.initialGoal, required this.preview});
  final String initialGoal;
  final bool preview;
  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialGoal);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your study goal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.preview
                    ? 'A small task for this visit. Saved locally in the preview only.'
                    : 'Your personal goal is saved when you join the study cycle.',
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'What will you work on?',
                controller: _controller,
                minLines: 2,
                maxLines: 4,
                maxLength: 160,
                textInputAction: TextInputAction.newline,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a goal before saving.'
                    : value.trim().length > 160
                    ? 'Keep your goal within 160 characters.'
                    : null,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: widget.preview ? 'Save preview goal' : 'Save goal',
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _controller.text.trim());
                  }
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
