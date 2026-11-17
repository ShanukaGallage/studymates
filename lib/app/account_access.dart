import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/controllers/auth_providers.dart';
import '../features/profile/presentation/controllers/profile_providers.dart';

enum AccountAccess { loading, signedOut, setupRequired, ready, unavailable }

// Auth supplies identity; the persisted profile determines setup completeness.
// Never use an Auth displayName or a previous user's cached profile as readiness.
final accountAccessProvider = Provider<AccountAccess>((ref) {
  final identity = ref.watch(authStateProvider);
  if (identity.errorCode != null && identity.status != AuthStatus.signedOut) {
    return AccountAccess.unavailable;
  }
  if (identity.status == AuthStatus.loading) return AccountAccess.loading;
  if (identity.userId == null) return AccountAccess.signedOut;
  final profile = ref.watch(currentProfileProvider);
  if (profile.isLoading) return AccountAccess.loading;
  if (profile.hasError) return AccountAccess.unavailable;
  final value = profile.asData?.value;
  if (value == null) return AccountAccess.setupRequired;
  if (value.id != identity.userId) return AccountAccess.loading;
  return value.displayName.trim().isEmpty
      ? AccountAccess.setupRequired
      : AccountAccess.ready;
});

String? accountRedirect(AccountAccess access, Uri uri) {
  const public = {'/login', '/signup', '/reset-password'};
  const gates = {...public, '/account-status', '/profile/setup'};
  const destinations = {
    '/home',
    '/discover',
    '/progress',
    '/profile',
    '/profile/edit',
    '/session',
    '/common-hall',
    '/scan',
    '/notifications',
    '/notification-settings',
  };
  final requested = gates.contains(uri.path)
      ? uri.queryParameters['from']
      : uri.path;
  final allowed =
      requested != null &&
      (destinations.contains(requested) ||
          RegExp(r'^/(sigs|subgroups|rooms)/[A-Za-z0-9_-]{1,128}$')
              .hasMatch(requested) ||
          RegExp(r'^/invitation/[A-HJ-KM-NP-Z2-9]{16}$').hasMatch(requested));
  final destination = allowed ? requested : '/home';
  String target(String path) =>
      Uri(path: path, queryParameters: {'from': destination}).toString();
  return switch (access) {
    AccountAccess.loading || AccountAccess.unavailable =>
      uri.path == '/account-status' ? null : target('/account-status'),
    AccountAccess.signedOut =>
      public.contains(uri.path) ? null : target('/login'),
    AccountAccess.setupRequired =>
      uri.path == '/profile/setup' ? null : target('/profile/setup'),
    AccountAccess.ready => gates.contains(uri.path) ? destination : null,
  };
}
