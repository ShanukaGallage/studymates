import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../widgets/profile_form.dart';

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({
    super.key,
    required this.profile,
    this.onSaved,
    this.onCancel,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile>? onSaved;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) =>
      ProfileForm(profile: profile, onSaved: onSaved, onCancel: onCancel);
}
