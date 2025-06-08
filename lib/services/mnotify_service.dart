import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_config.dart';

class MNotifyService {
  final String _apiKey;
  final String _baseUrl = 'https://apps.mnotify.net/smsapi';

  // Store OTP codes temporarily (in production, use secure storage or backend)
  final Map<String, String> _otpCodes = {};
  final Map<String, DateTime> _otpExpiry = {};

  MNotifyService({required String apiKey}) : _apiKey = apiKey;

  /// Send SMS to a single recipient
  Future<bool> sendSms({
    required String recipient,
    required String message,
    String? sender,
  }) async {
    try {
      // Ensure phone number format is correct (remove any spaces)
      final formattedRecipient = recipient.replaceAll(' ', '');

      // Truncate message if it's too long (mNotify has a limit)
      final truncatedMessage =
          message.length > 918 ? '${message.substring(0, 915)}...' : message;

      // Build query parameters manually to ensure proper encoding
      final Map<String, String> queryParams = {
        'key': _apiKey,
        'to': formattedRecipient,
        'msg': truncatedMessage,
        'sender_id': sender ?? AppConfig.mNotifySenderId,
      };

      // Create URL with properly encoded parameters
      final uri = Uri.parse(_baseUrl);
      final url = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
        queryParameters: queryParams,
      );

      print('Sending SMS to: $formattedRecipient');
      print('SMS URL: $url');

      // Use GET method for more reliable delivery with mNotify
      final response = await http.get(url);

      print('SMS Response Status: ${response.statusCode}');
      print('SMS Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('SMS Response Data: $data');
        // Check response code from mNotify
        return data['code'] == '1000'; // Successful code from mNotify
      }
      return false;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  /// Send SMS to multiple recipients
  Future<bool> sendBulkSms({
    required List<String> recipients,
    required String message,
    String? sender,
  }) async {
    try {
      if (recipients.isEmpty) {
        print('No recipients provided for bulk SMS');
        return false;
      }

      // Format phone numbers (remove spaces)
      final formattedRecipients =
          recipients.map((num) => num.replaceAll(' ', '')).toList();

      // Join phone numbers with comma
      final recipientsStr = formattedRecipients.join(',');

      // Truncate message if it's too long (mNotify has a limit)
      final truncatedMessage =
          message.length > 918 ? '${message.substring(0, 915)}...' : message;

      // Build query parameters manually to ensure proper encoding
      final Map<String, String> queryParams = {
        'key': _apiKey,
        'to': recipientsStr,
        'msg': truncatedMessage,
        'sender_id': sender ?? AppConfig.mNotifySenderId,
      };

      // Create URL with properly encoded parameters
      final uri = Uri.parse(_baseUrl);
      final url = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
        queryParameters: queryParams,
      );

      print('Sending bulk SMS to ${recipients.length} recipients');
      print('First recipient: ${recipients.first}');
      print('SMS URL: $url');

      // Use GET method for more reliable delivery with mNotify
      final response = await http.get(url);

      print('Bulk SMS Response Status: ${response.statusCode}');
      print('Bulk SMS Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Bulk SMS Response Data: $data');
        return data['code'] == '1000'; // Successful code from mNotify
      }
      return false;
    } catch (e) {
      print('Error sending bulk SMS: $e');
      return false;
    }
  }

  /// Generate and send OTP to phone number
  Future<bool> sendOtp({required String phoneNumber, String? sender}) async {
    try {
      // Generate 6-digit OTP
      final otp = _generateOtp();

      // Format phone number
      final formattedNumber = phoneNumber.replaceAll(' ', '');

      // Store OTP with 5-minute expiry
      _otpCodes[formattedNumber] = otp;
      _otpExpiry[formattedNumber] = DateTime.now().add(
        const Duration(minutes: 5),
      );

      // Create OTP message
      final message =
          'Your EduConnect verification code is: $otp. This code will expire in 5 minutes. Do not share this code with anyone.';

      // Send SMS
      final success = await sendSms(
        recipient: formattedNumber,
        message: message,
        sender: sender,
      );

      if (success) {
        print('OTP sent successfully to $formattedNumber');
      } else {
        // Clean up on failure
        _otpCodes.remove(formattedNumber);
        _otpExpiry.remove(formattedNumber);
      }

      return success;
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  /// Verify OTP for phone number
  bool verifyOtp({required String phoneNumber, required String otp}) {
    try {
      final formattedNumber = phoneNumber.replaceAll(' ', '');

      // Check if OTP exists
      if (!_otpCodes.containsKey(formattedNumber)) {
        print('No OTP found for number: $formattedNumber');
        return false;
      }

      // Check if OTP is expired
      final expiryTime = _otpExpiry[formattedNumber];
      if (expiryTime == null || DateTime.now().isAfter(expiryTime)) {
        print('OTP expired for number: $formattedNumber');
        // Clean up expired OTP
        _otpCodes.remove(formattedNumber);
        _otpExpiry.remove(formattedNumber);
        return false;
      }

      // Verify OTP
      final storedOtp = _otpCodes[formattedNumber];
      final isValid = storedOtp == otp;

      if (isValid) {
        print('OTP verified successfully for: $formattedNumber');
        // Clean up after successful verification
        _otpCodes.remove(formattedNumber);
        _otpExpiry.remove(formattedNumber);
      } else {
        print('Invalid OTP for number: $formattedNumber');
      }

      return isValid;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  /// Generate 6-digit OTP
  String _generateOtp() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return (100000 + (random % 900000)).toString();
  }

  /// Clear expired OTPs (call periodically)
  void clearExpiredOtps() {
    final now = DateTime.now();
    final expiredNumbers = <String>[];

    _otpExpiry.forEach((number, expiry) {
      if (now.isAfter(expiry)) {
        expiredNumbers.add(number);
      }
    });

    for (final number in expiredNumbers) {
      _otpCodes.remove(number);
      _otpExpiry.remove(number);
    }
  }
}
