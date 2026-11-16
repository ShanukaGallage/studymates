import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/community_providers.dart';

Future<void> showCreateSigDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _SigCreationDialog(),
);

Future<void> showCreateSubgroupDialog(
  BuildContext context, {
  required String sigId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _SubgroupDialog(sigId: sigId),
);

Future<void> showEditSubgroupDialog(
  BuildContext context, {
  required String sigId,
  required SubgroupSummary subgroup,
}) => showDialog<void>(
  context: context,
  builder: (_) => _SubgroupDialog(sigId: sigId, subgroup: subgroup),
);

class _SigCreationDialog extends ConsumerStatefulWidget {
  const _SigCreationDialog();

  @override
  ConsumerState<_SigCreationDialog> createState() => _SigCreationDialogState();
}

class _SigCreationDialogState extends ConsumerState<_SigCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(communityCatalogProvider.notifier)
          .createSig(
            name: _name.text,
            category: _category.text,
            description: _description.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _communityErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Create a SIG'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'SIG name',
              controller: _name,
              maxLength: 80,
              validator: (value) => _required(value, 80, 'Enter a SIG name.'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Category',
              controller: _category,
              maxLength: 40,
              validator: (value) => _required(value, 40, 'Enter a category.'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Description',
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              validator: (value) =>
                  _required(value, 500, 'Enter a description.'),
            ),
            if (_error != null) _ErrorText(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      AppButton(label: 'Create SIG', isLoading: _saving, onPressed: _save),
    ],
  );
}

class _SubgroupDialog extends ConsumerStatefulWidget {
  const _SubgroupDialog({required this.sigId, this.subgroup});

  final String sigId;
  final SubgroupSummary? subgroup;

  @override
  ConsumerState<_SubgroupDialog> createState() => _SubgroupDialogState();
}

class _SubgroupDialogState extends ConsumerState<_SubgroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.subgroup != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.subgroup?.name);
    _description = TextEditingController(text: widget.subgroup?.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(communityCatalogProvider.notifier);
      if (_editing) {
        await controller.updateSubgroup(
          sigId: widget.sigId,
          subgroupId: widget.subgroup!.id,
          name: _name.text,
          description: _description.text,
        );
      } else {
        await controller.createSubgroup(
          sigId: widget.sigId,
          name: _name.text,
          description: _description.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _communityErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(_editing ? 'Edit subgroup' : 'Create a subgroup'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Subgroup name',
              controller: _name,
              maxLength: 80,
              validator: (value) =>
                  _required(value, 80, 'Enter a subgroup name.'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Description',
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              validator: (value) =>
                  _required(value, 500, 'Enter a description.'),
            ),
            if (_error != null) _ErrorText(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      AppButton(
        label: _editing ? 'Save changes' : 'Create subgroup',
        isLoading: _saving,
        onPressed: _save,
      ),
    ],
  );
}

Future<bool> confirmSubgroupDeletion(
  BuildContext context,
  String subgroupName,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subgroup?'),
        content: Text(
          '“$subgroupName” will be closed and removed from discovery. Existing membership and history records are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

String? _required(String? value, int maxLength, String message) =>
    value == null || value.trim().isEmpty
    ? message
    : value.trim().length > maxLength
    ? 'Text is too long.'
    : null;

String _communityErrorMessage(Object error) {
  if (error is RepositoryException) {
    return switch (error.code) {
      RepositoryError.permissionDenied =>
        'Only the parent SIG owner can manage communities.',
      RepositoryError.invalidData =>
        'Check the required fields and their length limits.',
      RepositoryError.notFound => 'This community could not be found.',
      RepositoryError.membershipRequired => 'Join the parent SIG first.',
      RepositoryError.unavailable =>
        'The change could not be saved. Try again.',
    };
  }
  return 'The change could not be saved. Try again.';
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
