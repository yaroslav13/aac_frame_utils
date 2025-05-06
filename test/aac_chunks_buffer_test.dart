import 'dart:math';
import 'dart:typed_data';

import 'package:aac_frame_utils/src/aac_chunks_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('AacChunksBuffer stress test', () {
    late AacChunksBuffer buffer;

    setUp(() {
      buffer = AacChunksBuffer();
    });

    test('extracts single full frame', () {
      final frame = _buildAdtsFrame(payload: [1, 2, 3, 4, 5]);
      final frames = buffer.addChunk(frame);

      expect(frames.length, 1);
      expect(frames.first.length, 12); // 7 header + 5 payload
      expect(frames.first.sublist(7), [1, 2, 3, 4, 5]);
    });

    test('extracts multiple frames from one chunk', () {
      final frame1 = _buildAdtsFrame(payload: [10, 11, 12, 13, 14]);
      final frame2 = _buildAdtsFrame(payload: [20, 21, 22, 23, 24]);

      final combined = Uint8List.fromList([...frame1, ...frame2]);

      final frames = buffer.addChunk(combined);

      expect(frames.length, 2);
      expect(frames[0].sublist(7), [10, 11, 12, 13, 14]);
      expect(frames[1].sublist(7), [20, 21, 22, 23, 24]);
    });

    test('extracts frame split into two chunks', () {
      final frame = _buildAdtsFrame(payload: [7, 8, 9, 10, 11]);
      final part1 = frame.sublist(0, 5); // partial frame
      final part2 = frame.sublist(5); // rest of frame

      var frames = buffer.addChunk(part1);
      expect(frames, isEmpty);

      frames = buffer.addChunk(part2);
      expect(frames.length, 1);
      expect(frames.first.sublist(7), [7, 8, 9, 10, 11]);
    });

    test('clears buffer', () {
      final frame = _buildAdtsFrame(payload: [99, 100, 101, 102, 103]);
      buffer
        ..addChunk(frame)
        ..clear();

      // After clear, buffer should not return old frames
      final newFrames = buffer.addChunk(Uint8List.fromList([]));
      expect(newFrames, isEmpty);
    });

    test('handles randomly chunked stream', () {
      const frameCount = 10;
      final frames = List.generate(frameCount, (i) {
        final payload = List.generate(5, (j) => i * 10 + j);
        return _buildAdtsFrame(payload: payload);
      });

      final fullStream = Uint8List.fromList(frames.expand((f) => f).toList());

      final random = Random(42);
      final chunks = <Uint8List>[];

      var index = 0;
      while (index < fullStream.length) {
        final chunkSize =
            min(1 + random.nextInt(10), fullStream.length - index);
        chunks.add(fullStream.sublist(index, index + chunkSize));
        index += chunkSize;
      }

      final extractedFrames = <Uint8List>[];
      for (final chunk in chunks) {
        extractedFrames.addAll(buffer.addChunk(chunk));
      }

      expect(extractedFrames.length, frameCount);

      for (var i = 0; i < frameCount; i++) {
        final expectedPayload = List.generate(5, (j) => i * 10 + j);
        final frame = extractedFrames[i];
        expect(frame.length, 12);
        expect(frame.sublist(7), expectedPayload);
      }
    });

    test('ignores chunk with no ADTS header', () {
      final frame = _buildAdtsFrame(payload: [99, 100, 101, 102, 103]);
      final rawData = Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]);

      buffer.addChunk(frame);
      final frames = buffer.addChunk(rawData);

      expect(frames, isEmpty);

      final frame1 = _buildAdtsFrame(payload: [99, 100, 101, 102, 103]);
      final frames2 = buffer.addChunk(frame1);

      expect(frames2.length, 1);
    });
  });
}

Uint8List _buildAdtsFrame({required List<int> payload}) {
  final frameLength = 7 + payload.length;

  final header = Uint8List(7);

  header[0] = 0xFF; // syncword 0xFFF
  header[1] = 0xF1; // MPEG-4, layer always 0
  header[2] =
      0x50; // profile AAC LC + sample freq index + channel config partial
  header[3] =
      ((frameLength >> 11) & 0x03) | 0x80; // frame length part + fixed bits
  header[4] = (frameLength >> 3) & 0xFF; // frame length middle bits
  header[5] = ((frameLength & 0x07) << 5) |
      0x1F; // frame length last 3 bits + buffer fullness part
  header[6] = 0xFC; // buffer fullness + number of AAC frames (always 1)

  return Uint8List.fromList([...header, ...payload]);
}
