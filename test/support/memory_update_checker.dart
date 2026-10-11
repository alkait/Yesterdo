import 'package:remind_me/platform/update_checker.dart';

/// A checker that answers what it was given, so a test can say what the
/// hoster has.
class MemoryUpdateChecker implements UpdateChecker {
  const MemoryUpdateChecker([this.answer]);

  final AvailableBuild? answer;

  @override
  Future<AvailableBuild?> latest() => Future.value(answer);
}
