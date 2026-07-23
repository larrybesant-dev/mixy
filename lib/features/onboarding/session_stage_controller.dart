import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/first_run_service.dart';

enum SessionStage { loading, firstTime, returningUser }

final sessionStageProvider =
    StateNotifierProvider<SessionStageController, SessionStage>((ref) {
      return SessionStageController()..restore();
    });

class SessionStageController extends StateNotifier<SessionStage> {
  SessionStageController() : super(SessionStage.loading);

  bool _restored = false;

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;

    final isFirstRun = await FirstRunService.isFirstRun();
    state = isFirstRun ? SessionStage.firstTime : SessionStage.returningUser;
  }

  Future<void> completeFirstSessionAction() async {
    await FirstRunService.markOnboardingSeen();
    state = SessionStage.returningUser;
  }
}




