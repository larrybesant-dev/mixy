import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/user_gateway.dart';
import '../../../models/user_model.dart';

final userProvider = FutureProvider.family<UserModel?, String>((
  ref,
  userId,
) async {
  final userGateway = ref.watch(userGatewayProvider);
  final doc = await userGateway.getUser(userId);
  if (!doc.exists) return null;
  final data = doc.data();
  if (data == null) return null;
  return UserModel.fromJson({...data, 'id': doc.id});
});




