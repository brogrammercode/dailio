import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailio/features/attendance/attendance_error.dart';

void main() {
  test('uses safe server messages and hides transport details', () {
    expect(
      attendanceErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/branches/private/attendance'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/branches/private/attendance'),
            statusCode: 422,
            data: {'message': 'Location evidence is required'},
          ),
        ),
      ),
      'Location evidence is required',
    );
    expect(
      attendanceErrorMessage(Exception('database password leaked')),
      'We could not complete that attendance action. Please try again.',
    );
  });
}
