import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_text_field.dart';
import '../features/invites/data/invitation_token.dart';
import '../features/invites/presentation/controllers/invitation_providers.dart';
import '../features/invites/presentation/screens/invitation_display_screen.dart';
import '../features/invites/presentation/screens/invitation_preview_screen.dart';
import '../features/invites/presentation/screens/invite_scanner_screen.dart';
import 'invites_flow_fixtures.dart';

void main() => runApp(const InvitesFlowPreview());

class InvitesFlowPreview extends StatefulWidget {
  const InvitesFlowPreview({super.key});
  @override
  State<InvitesFlowPreview> createState() => _InvitesFlowPreviewState();
}

class _InvitesFlowPreviewState extends State<InvitesFlowPreview> {
  final _observer = RouteObserver<ModalRoute<dynamic>>();
  final _manual = TextEditingController();
  final _form = GlobalKey<FormState>();
  var _service = InvitesFlowFixtureService(InvitesFlowScenario.valid);
  int _revision = 0;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _preview(BuildContext context, String token) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvitationPreviewScreen(
          opaqueToken: token,
          isFixture: true,
          onRequestMembership: _service.completeMembershipForPreview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    key: ValueKey(_revision),
    overrides: [invitationServiceProvider.overrideWithValue(_service)],
    child: MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_observer],
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Invitations · fixture preview')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const Text(
                  'Local fixtures only. No live invitation, membership or seat is created.',
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<InvitesFlowScenario>(
                  initialValue: _service.scenario,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Fixture scenario',
                  ),
                  items: [
                    for (final scenario in InvitesFlowScenario.values)
                      DropdownMenuItem(
                        value: scenario,
                        child: Text(switch (scenario) {
                          InvitesFlowScenario.seatRace => 'Full after preview',
                          InvitesFlowScenario.networkError =>
                            'Lookup error once',
                          InvitesFlowScenario.admissionError =>
                            'Join error once',
                          InvitesFlowScenario.longText =>
                            'Long room/community names',
                          _ => scenario.name,
                        }),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _service = InvitesFlowFixtureService(value);
                        _revision++;
                        _manual.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Display invitation QR and code',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => InvitationDisplayScreen(
                        opaqueToken: _service.token,
                        roomTitle: 'ESP32 Study Room',
                        isFixture: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Scan invitation',
                  onPressed: () async {
                    final token = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (scanContext) => InviteScannerScreen(
                          routeObserver: _observer,
                          parseQr: InvitationTokenParser.parseQr,
                          parseManual: InvitationTokenParser.parseManual,
                          onResult: (token) =>
                              Navigator.of(scanContext).pop(token),
                          onCancel: () => Navigator.of(scanContext).pop(),
                        ),
                      ),
                    );
                    if (context.mounted && token != null) {
                      _preview(context, token);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Manual invitation code',
                        controller: _manual,
                        maxLength: 128,
                        validator: (value) =>
                            InvitationTokenParser.parseManual(value) == null
                            ? 'Enter a valid 16-character code.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Preview typed code',
                        onPressed: () {
                          if (_form.currentState!.validate()) {
                            _preview(
                              context,
                              InvitationTokenParser.parseManual(_manual.text)!,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Open selected fixture preview',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _preview(context, _service.token),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
