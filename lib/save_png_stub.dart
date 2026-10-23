import 'dart:typed_data';

/// Non-web platforms: not implemented yet. Returns false so the UI can say so.
/// TODO: mobile/desktop saving (e.g. save to gallery or share sheet).
Future<bool> savePng(Uint8List bytes, String fileName) async => false;
