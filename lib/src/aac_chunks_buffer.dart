import 'dart:typed_data';

/// Representation of an audio chunk
typedef AudioChunk = Uint8List;

/// A class that buffers AAC audio chunks and extracts complete ADTS frames
final class AacChunksBuffer {
  var _buffer = <int>[];

  /// Adds a chunk of audio data to the buffer and extracts complete ADTS frames
  List<AudioChunk> addChunk(AudioChunk chunk) {
    _buffer.addAll(chunk);

    final extractedFrames = <AudioChunk>[];
    var bufferIndex = 0;

    while (bufferIndex <= _buffer.length - 7) {
      final headerIndex =
          _findNextAdtsHeaderIndex(_buffer.sublist(bufferIndex));

      if (headerIndex == -1) {
        break;
      }

      final absoluteHeaderIndex = bufferIndex + headerIndex;

      if (_buffer.length < absoluteHeaderIndex + 7) {
        break;
      }

      final frameLength = _getAdtsFrameLength(_buffer, absoluteHeaderIndex);

      if (_buffer.length >= absoluteHeaderIndex + frameLength) {
        final frame = Uint8List.fromList(
          _buffer.sublist(
            absoluteHeaderIndex,
            absoluteHeaderIndex + frameLength,
          ),
        );

        extractedFrames.add(frame);
        bufferIndex = absoluteHeaderIndex + frameLength;
      } else {
        break;
      }
    }

    _buffer = _buffer.sublist(bufferIndex);

    return extractedFrames;
  }

  int _getAdtsFrameLength(List<int> data, int index) {
    return ((data[index + 3] & 0x03) << 11) |
        ((data[index + 4] & 0xFF) << 3) |
        ((data[index + 5] & 0xE0) >> 5);
  }

  int _findNextAdtsHeaderIndex(List<int> data) {
    for (var i = 0; i <= data.length - 7; i++) {
      if (data[i] == 0xFF && (data[i + 1] & 0xF0) == 0xF0) {
        return i;
      }
    }
    return -1;
  }

  /// Clears the buffer
  void clear() {
    _buffer.clear();
  }
}
