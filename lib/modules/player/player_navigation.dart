import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import 'player_route_args.dart';

/// Oynatıcı rotasını açar.
Future<void> openPlayerRoute(PlayerScreenArgs args) async {
  await Get.toNamed(AppRoutes.player, arguments: args);
}
