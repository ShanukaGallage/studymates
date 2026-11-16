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

class RoomCreationOptions {
  const RoomCreationOptions(this.title, this.capacity, this.isPrivate);
  final String title;
  final int capacity;
  final bool isPrivate;
}

Future<RoomCreationOptions?> studyRoomDialog(BuildContext context) =>
    showDialog<RoomCreationOptions>(
      context: context,
      builder: (_) => const _RoomCreationDialog(),
    );

class _RoomCreationDialog extends StatefulWidget {
  const _RoomCreationDialog();
  @override
  State<_RoomCreationDialog> createState() => _RoomCreationDialogState();
}

class _RoomCreationDialogState extends State<_RoomCreationDialog> {
  final _title = TextEditingController();
  final _capacity = TextEditingController(text: '6');
  final _form = GlobalKey<FormState>();
  bool _private = false;
  @override
  void dispose() {
    _title.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create study room'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Room name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a room name.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Desk capacity (2–40)',
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return n == null || n < 2 || n > 40
                    ? 'Choose 2–40 desks.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private room'),
              value: _private,
              onChanged: (v) => setState(() => _private = v),
            ),
            Text(
              _private
                  ? 'Visible in discovery. An invitation is required to enter; the host can enter directly.'
                  : 'Public room. Eligible subgroup members can enter without an invitation.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              RoomCreationOptions(
                _title.text.trim(),
                int.parse(_capacity.text.trim()),
                _private,
              ),
            );
          }
        },
        child: const Text('Create'),
      ),
    ],
  );
}
