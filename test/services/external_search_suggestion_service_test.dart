import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:selene/services/external_search_suggestion_service.dart';

void main() {
  test('aggregates and dedupes suggestions from multiple external providers',
      () async {
    final service = ExternalSearchSuggestionService(
      httpClient: _FakeHttpClient((request) async {
        final url = request.url.toString();

        if (url.contains('video.qq.com')) {
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <String, dynamic>{
                'result_list': <String, dynamic>{
                  'item_list': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'view': <String, dynamic>{
                        'lines': <Map<String, dynamic>>[
                          <String, dynamic>{'text': '<em>世界的主人</em>'},
                        ],
                      },
                    },
                    <String, dynamic>{
                      'view': <String, dynamic>{
                        'lines': <Map<String, dynamic>>[
                          <String, dynamic>{'text': '时间的证人'},
                        ],
                      },
                    },
                  ],
                },
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        if (url.contains('iqiyi.com')) {
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <String, dynamic>{
                'keyWordData': <Map<String, dynamic>>[
                  <String, dynamic>{'name': '世界的主人'},
                  <String, dynamic>{'name': '世界的主人电影'},
                ],
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        if (url.contains('mgtv.com')) {
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <String, dynamic>{
                'suggest': <Map<String, dynamic>>[
                  <String, dynamic>{'title': '世界的主人电影'},
                  <String, dynamic>{'title': '世界大战日记'},
                ],
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        return http.Response('', 404);
      }),
    );

    final suggestions = await service.fetchSuggestions('SJDZR');

    expect(
      suggestions,
      <String>[
        '世界的主人',
        '时间的证人',
        '世界的主人电影',
        '世界大战日记',
      ],
    );
  });

  test('skips external suggestion lookup for non-initial queries', () async {
    var requestCount = 0;
    final service = ExternalSearchSuggestionService(
      httpClient: _FakeHttpClient((request) async {
        requestCount++;
        return http.Response('', 500);
      }),
    );

    final suggestions = await service.fetchSuggestions('世界的主人');

    expect(suggestions, isEmpty);
    expect(requestCount, 0);
  });

  test('keeps aggregated suggestions beyond twelve items', () async {
    final service = ExternalSearchSuggestionService(
      httpClient: _FakeHttpClient((request) async {
        final url = request.url.toString();

        if (url.contains('video.qq.com')) {
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <String, dynamic>{
                'result_list': <String, dynamic>{
                  'item_list': List<Map<String, dynamic>>.generate(
                    5,
                    (index) => <String, dynamic>{
                      'view': <String, dynamic>{
                        'lines': <Map<String, dynamic>>[
                          <String, dynamic>{'text': '腾讯$index'},
                        ],
                      },
                    },
                  ),
                },
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        if (url.contains('iqiyi.com')) {
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <String, dynamic>{
                'keyWordData': List<Map<String, dynamic>>.generate(
                  5,
                  (index) => <String, dynamic>{'name': '爱奇艺$index'},
                ),
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        if (url.contains('mgtv.com')) {
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <String, dynamic>{
                'suggest': List<Map<String, dynamic>>.generate(
                  5,
                  (index) => <String, dynamic>{'title': '芒果$index'},
                ),
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        return http.Response('', 404);
      }),
    );

    final suggestions = await service.fetchSuggestions('YY');

    expect(suggestions.length, 15);
    expect(suggestions.first, '腾讯0');
    expect(suggestions.last, '芒果4');
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
