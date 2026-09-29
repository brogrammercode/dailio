import 'dart:io';

import 'package:dio/dio.dart';

import '../network/interceptors/logging_interceptor.dart';

/// Uploads a picked image directly to Cloudinary using a server-issued
/// signature. The API receives only the resulting scoped storage key, so post
/// publishing does not carry a large base64 body through the application API.
Future<Map<String, dynamic>> uploadSignedCloudinaryImage({
  required Dio api,
  required String signaturePath,
  required String filename,
  required String filePath,
}) async {
  if (await File(filePath).length() > 20 * 1024 * 1024) {
    throw const FormatException('Image must be smaller than 20 MB');
  }
  final signatureResponse = await api.post(
    signaturePath,
    data: {'filename': filename},
  );
  final signature = Map<String, dynamic>.from(
    signatureResponse.data['data'] as Map,
  );
  final uploadDio = Dio()..interceptors.add(LoggingInterceptor());
  final response = await uploadDio.post(
    'https://api.cloudinary.com/v1_1/${signature['cloud_name']}/auto/upload',
    data: FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      'api_key': signature['api_key'],
      'timestamp': signature['timestamp'].toString(),
      'signature': signature['signature'],
      'folder': signature['folder'],
      'public_id': signature['public_id'],
      'type': signature['type'],
    }),
    options: Options(contentType: 'multipart/form-data'),
  );
  if (response.statusCode != 200 || response.data is! Map) {
    throw const FormatException('Media upload failed');
  }
  final uploaded = Map<String, dynamic>.from(response.data as Map);
  return {
    'storage_key': signature['storage_key'],
    'format': uploaded['format']?.toString(),
  };
}
