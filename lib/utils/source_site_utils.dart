import '../models/search_resource.dart';

Uri? resolveSourceSiteRootUri(String? rawUrl) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }

  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
}

Uri? resolveSearchResourceSiteRootUri(SearchResource resource) {
  return resolveSourceSiteRootUri(resource.api) ??
      resolveSourceSiteRootUri(resource.detail);
}
