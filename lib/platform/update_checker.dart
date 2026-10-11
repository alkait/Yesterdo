import 'dart:convert';
import 'dart:io';

/// Whether this is the App Store build, set with `--dart-define=APP_STORE=true`
/// by `tool/appstore.sh`. The store updates it, so it never asks the hoster
/// and Settings offers no Update row.
const storeBuild = bool.fromEnvironment('APP_STORE');

/// A build the hoster has, as it answers `GET /<bundleId>/latest`.
class AvailableBuild {
  const AvailableBuild({
    required this.version,
    required this.build,
    required this.url,
  });

  /// Reads the hoster's answer. A build it cannot read counts as none.
  static AvailableBuild? fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final url = json['url'];
    final build = switch (json['build']) {
      final int n => n,
      final String s => int.tryParse(s),
      _ => null,
    };
    if (version is! String || url is! String || build == null) return null;
    return AvailableBuild(version: version, build: build, url: url);
  }

  final String version;

  /// The number after the `+` in `pubspec.yaml`, which goes up by one on
  /// every deploy, so it alone says which build is newer.
  final int build;

  /// The install page, to be opened in the browser.
  final String url;

  String get label => '$version ($build)';
}

/// Asks where the builds are hosted which build is the newest. One
/// implementation asks the hoster, tests supply an answer of their own.
abstract class UpdateChecker {
  /// The newest build the hoster has, or null when it cannot be reached.
  Future<AvailableBuild?> latest();
}

/// Never knows of a newer build, which is what the app has until `main`
/// binds the hoster, and what widget tests have.
class NoUpdateChecker implements UpdateChecker {
  const NoUpdateChecker();

  @override
  Future<AvailableBuild?> latest() => Future.value(null);
}

/// The shipping checker: one request to the ios-app-hoster on the Pi.
/// Anything short of a readable answer is no answer; nothing is retried
/// and nothing is said, since the check is a courtesy, not a need.
class HosterUpdateChecker implements UpdateChecker {
  const HosterUpdateChecker({this.endpoint = defaultEndpoint});

  static const defaultEndpoint =
      'https://ios-apps.alkait.xyz/com.alkait.yesterdo/latest';

  static const _timeout = Duration(seconds: 10);

  final String endpoint;

  @override
  Future<AvailableBuild?> latest() async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(endpoint));
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      return json is Map<String, Object?> ? AvailableBuild.fromJson(json) : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
