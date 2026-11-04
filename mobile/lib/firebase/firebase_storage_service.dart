import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../services/services.dart';

/// Firebase Cloud Storage implementation for reports export.
///
/// Requirement: Upload to `reports/{uid}/{fileName}` under security rules.
class FirebaseStorageService implements StorageService {
  FirebaseStorageService([FirebaseStorage? storage]) : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;
  @override
  Stream<UploadProgress> uploadReport({required File file, required String uid}) async* {
    final ref = _storage.ref('reports/$uid/${file.uri.pathSegments.last}');
    final task = ref.putFile(file, SettableMetadata(contentType: 'application/pdf'));
    await for (final snapshot in task.snapshotEvents) {
      yield UploadProgress(fraction: snapshot.totalBytes == 0 ? 0 : snapshot.bytesTransferred / snapshot.totalBytes);
    }
    yield UploadProgress(fraction: 1, downloadUrl: await ref.getDownloadURL());
  }
}
