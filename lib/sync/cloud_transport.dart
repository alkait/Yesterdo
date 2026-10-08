import 'package:flutter/services.dart';

import '../data/sync_record.dart';

/// The way to the cloud: iCloud, through CloudKit. It only ever moves
/// records; what they mean, and whose write wins, is the store's. One
/// implementation talks to the device, tests supply a cloud of their own.
abstract class CloudTransport {
  /// Whether there is an iCloud account to sync through. Without one the
  /// app stays local and nothing is said about it.
  Future<bool> available();

  /// Everything written or removed in the cloud since [token], or since
  /// the beginning for null, with the token to hand back next time.
  Future<SyncBatch> pull(String? token);

  /// Hands a batch up. Throws when it could not be sent, so it is kept to
  /// be sent again.
  Future<void> push(SyncBatch batch);

  /// Runs [handler] when the cloud says another device has written.
  void onChange(void Function() handler);
}

/// No cloud at all, which is what the app has until `main` binds the
/// device, and what widget tests have.
class NoCloudTransport implements CloudTransport {
  const NoCloudTransport();

  @override
  Future<bool> available() => Future.value(false);

  @override
  Future<SyncBatch> pull(String? token) => Future.value(const SyncBatch());

  @override
  Future<void> push(SyncBatch batch) => Future.value();

  @override
  void onChange(void Function() handler) {}
}

/// The shipping transport: a method channel into `CloudBridge`.
class MethodChannelCloudTransport implements CloudTransport {
  const MethodChannelCloudTransport();

  static const _channel = MethodChannel('remindme/cloud');

  @override
  Future<bool> available() async =>
      await _channel.invokeMethod<bool>('available') ?? false;

  @override
  Future<SyncBatch> pull(String? token) async {
    final json = await _channel.invokeMethod<Map<Object?, Object?>>(
      'pull',
      token,
    );
    return SyncBatch.fromJson(_deep(json ?? const {}));
  }

  @override
  Future<void> push(SyncBatch batch) =>
      _channel.invokeMethod('push', batch.toJson());

  @override
  void onChange(void Function() handler) =>
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') handler();
        return null;
      });

  /// The channel hands maps back keyed by `Object?`; the records read them
  /// keyed by `String`.
  static Map<String, Object?> _deep(Map<Object?, Object?> json) => {
    for (final MapEntry(:key, :value) in json.entries)
      key! as String: switch (value) {
        final Map<Object?, Object?> map => _deep(map),
        final List<Object?> list => [
          for (final each in list)
            each is Map<Object?, Object?> ? _deep(each) : each,
        ],
        _ => value,
      },
  };
}
