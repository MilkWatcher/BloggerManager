import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class EmailService {
  
  static const String _serviceId = 'service_5t07rcm';
  static const String _banTemplateId = 'template_mwqqey2';
  static const String _warnTemplateId = 'template_939qnf8';
  static const String _publicKey = '6jLd1pgKi4PbZgkpj';
  static const String _emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  Future<void> sendBanNotification({
    required String toEmail,
    required String toName,
    String? reason,
    required String duration,
    required DateTime expiryDate,
  }) async {
    try {
      final Map<String, dynamic> templateParams = {
        'to_email': toEmail,
        'to_name': toName,
        'reason': reason ?? 'No reason provided',
        'duration': _formatDuration(duration),
        'expiry_date': expiryDate.toLocal().toString().split('.').first,
      };

      await _sendEmail(_banTemplateId, templateParams);
      developer.log('Ban notification sent to $toEmail', name: 'EmailService');
    } catch (e) {
      developer.log('Failed to send ban notification: $e', error: e, name: 'EmailService');
    }
  }

  Future<void> sendWarningNotification({
    required String toEmail,
    required String toName,
    String? reason,
  }) async {
    try {
      final Map<String, dynamic> templateParams = {
        'to_email': toEmail,
        'to_name': toName,
        'reason': reason ?? 'No reason provided',
      };

      await _sendEmail(_warnTemplateId, templateParams);
      developer.log('Warning notification sent to $toEmail', name: 'EmailService');
    } catch (e) {
      developer.log('Failed to send warning notification: $e', error: e, name: 'EmailService');
    }
  }

  Future<void> _sendEmail(String templateId, Map<String, dynamic> templateParams) async {
    final response = await http.post(
      Uri.parse(_emailJsUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _serviceId,
        'template_id': templateId,
        'user_id': _publicKey,
        'template_params': templateParams,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('EmailJS returned status ${response.statusCode}: ${response.body}');
    }
  }

  String _formatDuration(String duration) {
    switch (duration) {
      case '1_day':
        return '1 day';
      case '3_days':
        return '3 days';
      case '1_week':
        return '1 week';
      case '1_month':
        return '1 month';
      case '1_year':
        return '1 year';
      default:
        return duration;
    }
  }
}
