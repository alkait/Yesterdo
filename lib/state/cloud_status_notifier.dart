import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/cloud_status.dart';

/// Where the sync stands, for Settings to read. Set by the sync as it
/// goes, never by a widget.
class CloudStatusNotifier extends Notifier<CloudStatus> {
  @override
  CloudStatus build() => const CloudStatus();

  void set(CloudStatus status) => state = status;
}
