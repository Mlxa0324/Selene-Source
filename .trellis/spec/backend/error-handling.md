# Error Handling

> Services should return predictable results to the UI and keep recovery behavior close to the failing integration.

## Overview

The project uses a mix of result wrappers and graceful fallbacks. Remote API methods generally return `ApiResponse<T>` from `lib/services/api_service.dart`. Local settings and parsing code often catch exceptions, log a concise message with `debugPrint`, and return a safe default or `null`.

Existing examples:

- `ApiResponse<T>` in `lib/services/api_service.dart` carries `success`, `data`, `message`, and `statusCode`.
- `ApiService._handleResponse` maps 401 to session cleanup and login navigation, maps common HTTP status codes to Chinese user-facing messages, and wraps successful JSON parsing.
- `UserDataService.getVideoSkipSettings` catches malformed persisted JSON, logs the failure, and returns `null`.
- `SearchEvent.fromJson` in `lib/models/search_result.dart` throws for unknown event types because the caller cannot safely infer event semantics.

## Error Types

- Use `ApiResponse<T>` for recoverable remote API results that the UI can present or branch on.
- Use `Exception` only for unrecoverable internal contract violations or private helper failures, such as missing server URL in `_buildUrl`.
- Use nullable return values for optional cached/local data where absence is valid.
- Use empty collections for list-like data when the normal UI can render an empty state.

## Error Handling Patterns

- Keep `try`/`catch` around parsing, IO, and network boundaries.
- Return localized, user-understandable messages from service methods that surface directly to UI.
- Preserve authentication recovery behavior: 401 clears invalid cookies but keeps server configuration so TV settings/login flows can recover.
- Check `context.mounted` before navigation after async work.
- Do not swallow errors that would make state ambiguous; log enough context to identify the feature and input category.

## API Error Responses

Remote service methods should normalize failures through `ApiResponse.error(message, statusCode: code)`. Current conventions:

- 401: clear session cookies, optionally navigate to `LoginScreen`, and return `登录已过期，请重新登录`.
- 400/403/404/500: map to concise Chinese messages when the response body does not provide `message` or `error`.
- Other non-2xx: return `网络请求失败 (<statusCode>)`.
- Successful responses should parse JSON in one place and apply a typed mapper where possible.

## Common Mistakes

- Throwing directly from public service methods when existing callers expect `ApiResponse.error`.
- Navigating after async work without checking `context.mounted`.
- Clearing saved server/account configuration on 401 when only session cookies are invalid.
- Catching an exception and returning a default without a `debugPrint` in behavior that is hard to diagnose.
