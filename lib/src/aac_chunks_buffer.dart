import 'dart:typed_data';

/// Representation of an audio chunk
typedef AudioChunk = Uint8List;

/// A class that buffers AAC audio chunks and extracts complete ADTS frames
final class AacChunksBuffer {
  static const _adtsHeaderLength = 7;

  final _buffer = <int>[];

  /// Adds a chunk of audio data to the buffer and extracts complete ADTS frames
  AudioChunk addChunk(AudioChunk chunk) {
    _buffer.addAll(chunk);

    final frames = <int>[];
    var currentIndex = 0;

    while (_buffer.length - currentIndex >= _adtsHeaderLength) {
      if (_buffer[currentIndex] != 0xFF ||
          (_buffer[currentIndex + 1] & 0xF0) != 0xF0) {
        currentIndex++;
        continue;
      }

      final frameLength = ((_buffer[currentIndex + 3] & 0x03) << 11) |
          (_buffer[currentIndex + 4] << 3) |
          ((_buffer[currentIndex + 5] & 0xE0) >> 5);

      if (_buffer.length - currentIndex < frameLength) break;

      frames.addAll(
        _buffer.sublist(currentIndex, currentIndex + frameLength),
      );
      currentIndex += frameLength;
    }

    if (currentIndex > 0) {
      _buffer.removeRange(0, currentIndex);
    }

    return Uint8List.fromList(frames);
  }

  /// Clears the buffer
  void clear() {
    _buffer.clear();
  }
}
