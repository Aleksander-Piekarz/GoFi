import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/models/user.dart';

final userProvider = StateProvider<User?>((ref) => null);
final authTokenProvider = StateProvider<String?>((ref) => null);