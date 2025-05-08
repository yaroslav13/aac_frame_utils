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

    while (_buffer.length >= _adtsHeaderLength) {
      // Check for ADTS syncword (0xFFF)
      if (!(_buffer[0] == 0xFF && (_buffer[1] & 0xF0) == 0xF0)) {
        // Not a valid header; discard until next possible header
        _buffer.removeAt(0);
        continue;
      }

      // Extract frame length (13 bits) from ADTS header
      final frameLength = ((_buffer[3] & 0x03) << 11) |
          (_buffer[4] << 3) |
          ((_buffer[5] & 0xE0) >> 5);

      if (_buffer.length < frameLength) {
        // Wait for more data
        break;
      }

      // Extract full frame and add to output
      frames.addAll(_buffer.sublist(0, frameLength));
      _buffer.removeRange(0, frameLength);
    }

    return Uint8List.fromList(frames);
  }

  /// Clears the buffer
  void clear() {
    _buffer.clear();
  }
}
