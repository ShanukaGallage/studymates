import 'package:material_ui/material_ui.dart';

Future<String?> studyTitleDialog(BuildContext context, String title) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLength: 80,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name (1–80 characters)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  // Dialog route may still be animating; don't dispose its controller mid-frame.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return value;
}