import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_config.dart';

class MNotifyService {
  final String _apiKey;
  final String _baseUrl = 'https://apps.mnotify.net/smsapi';

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

      // URL encode the message and sender
      final encodedMessage = Uri.encodeComponent(message);
      final actualSender = sender ?? AppConfig.mNotifySenderId;
      final encodedSender = Uri.encodeComponent(actualSender);

      final url = Uri.parse(
        '$_baseUrl?key=$_apiKey&to=$formattedRecipient&msg=$encodedMessage&sender_id=$encodedSender',
      );

      print('Sending SMS to: $formattedRecipient');
      print('SMS URL: $url');

      final response = await http.post(url);

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

      // URL encode the message and sender
      final encodedMessage = Uri.encodeComponent(message);
      final actualSender = sender ?? AppConfig.mNotifySenderId;
      final encodedSender = Uri.encodeComponent(actualSender);

      final url = Uri.parse(
        '$_baseUrl?key=$_apiKey&to=$recipientsStr&msg=$encodedMessage&sender_id=$encodedSender',
      );

      print('Sending bulk SMS to ${recipients.length} recipients');
      print('First recipient: ${recipients.first}');
      print('SMS URL: $url');

      final response = await http.post(url);

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
}
