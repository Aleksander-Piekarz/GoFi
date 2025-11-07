import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'providers.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final api = ref.read(apiClientProvider);
  return UserService(api);
});

class UserService {
  UserService(this._api);
  final ApiClient _api;

  Future<void> updateSettings({String? unitSystem, bool? notifEnabled}) async {
    await _api.put('/users/me/settings', body: {
      if (unitSystem != null) 'unitSystem': unitSystem,
      if (notifEnabled != null) 'notifEnabled': notifEnabled,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post('/users/me/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
