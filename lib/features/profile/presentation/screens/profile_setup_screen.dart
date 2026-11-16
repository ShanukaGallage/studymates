import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../widgets/profile_form.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key, this.onComplete, this.onCancel});

  final ValueChanged<UserProfile>? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) =>
      ProfileForm(onSaved: onComplete, onCancel: onCancel);
}
