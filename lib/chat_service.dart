import 'dart:convert';
import 'dart:io';

class OllamaDelta {
  const OllamaDelta({this.thinking = '', this.content = ''});

  final String thinking;
  final String content;
}

class OllamaChatService {
  OllamaChatService({Uri? baseUri})
    : _baseUri = baseUri ?? Uri.parse('http://10.0.2.2:11434');

  final Uri _baseUri;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  Stream<OllamaDelta> chat({
    required String model,
    required List<Map<String, String>> messages,
  }) async* {
    final request = await _client.postUrl(_baseUri.resolve('/api/chat'));
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({'model': model, 'messages': messages, 'stream': true}),
    );

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final details = await response.transform(utf8.decoder).join();
      throw HttpException(
        'Ollama HTTP ${response.statusCode}: $details',
        uri: _baseUri,
      );
    }

    final thinkParser = _ThinkTagParser();
    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      final payload = jsonDecode(line) as Map<String, dynamic>;
      if (payload['error'] != null) {
        throw HttpException(payload['error'].toString(), uri: _baseUri);
      }

      final message = payload['message'] as Map<String, dynamic>?;
      final explicitThinking = message?['thinking'] as String? ?? '';
      final parsed = thinkParser.add(message?['content'] as String? ?? '');
      final delta = OllamaDelta(
        thinking: '$explicitThinking${parsed.thinking}',
        content: parsed.content,
      );
      if (delta.thinking.isNotEmpty || delta.content.isNotEmpty) {
        yield delta;
      }

      if (payload['done'] == true) break;
    }

    final remaining = thinkParser.finish();
    if (remaining.thinking.isNotEmpty || remaining.content.isNotEmpty) {
      yield remaining;
    }
  }

  void dispose() => _client.close(force: true);
}

class _ThinkTagParser {
  final StringBuffer _pending = StringBuffer();
  bool _isThinking = false;

  OllamaDelta add(String chunk) {
    _pending.write(chunk);
    return _drain(finalChunk: false);
  }

  OllamaDelta finish() => _drain(finalChunk: true);

  OllamaDelta _drain({required bool finalChunk}) {
    var remaining = _pending.toString();
    _pending.clear();
    final thinking = StringBuffer();
    final content = StringBuffer();

    while (remaining.isNotEmpty) {
      final tag = _isThinking ? '</think>' : '<think>';
      final tagIndex = remaining.indexOf(tag);
      if (tagIndex >= 0) {
        _writeText(remaining.substring(0, tagIndex), thinking, content);
        remaining = remaining.substring(tagIndex + tag.length);
        _isThinking = !_isThinking;
        continue;
      }

      if (finalChunk) {
        _writeText(remaining, thinking, content);
        remaining = '';
      } else {
        var preservedLength = 0;
        for (var length = 1; length < tag.length; length++) {
          if (remaining.endsWith(tag.substring(0, length))) {
            preservedLength = length;
          }
        }
        final readyLength = remaining.length - preservedLength;
        _writeText(remaining.substring(0, readyLength), thinking, content);
        remaining = remaining.substring(readyLength);
        _pending.write(remaining);
        remaining = '';
      }
    }

    return OllamaDelta(
      thinking: thinking.toString(),
      content: content.toString(),
    );
  }

  void _writeText(String text, StringBuffer thinking, StringBuffer content) {
    if (_isThinking) {
      thinking.write(text);
    } else {
      content.write(text);
    }
  }
}
