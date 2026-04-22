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
    final formattedDuration = _formatDuration(duration);
    final formattedExpiry = expiryDate.toLocal().toString().split('.').first;
    final body = '''
        <p>Your <strong>Blogger Manager</strong> account has been suspended.</p>
        <table style="width:100%;border-collapse:collapse;background:#EAEAF4;border-radius:8px;margin:20px 0;padding:16px;">
          <tr>
            <td style="padding:8px 16px;color:#8A80C4;font-size:13px;width:110px;">Reason</td>
            <td style="padding:8px 16px;color:#1E1A3C;font-weight:600;">${reason ?? 'No reason provided'}</td>
          </tr>
          <tr>
            <td style="padding:8px 16px;color:#8A80C4;font-size:13px;">Duration</td>
            <td style="padding:8px 16px;color:#1E1A3C;font-weight:600;">$formattedDuration</td>
          </tr>
          <tr>
            <td style="padding:8px 16px;color:#8A80C4;font-size:13px;">Expires</td>
            <td style="padding:8px 16px;color:#1E1A3C;font-weight:600;">$formattedExpiry</td>
          </tr>
        </table>
        <p>If you believe this was a mistake, please contact your platform administrator.</p>
      ''';
    final html = _buildEmailHtml(title: 'Account Suspended', recipientName: toName, bodyHtml: body);
    await _sendEmail(_banTemplateId, _params(toEmail: toEmail, toName: toName, html: html));
    developer.log('Ban notification sent to $toEmail', name: 'EmailService');
  }

  Future<void> sendWarningNotification({
    required String toEmail,
    required String toName,
    String? reason,
  }) async {
    final body = '''
        <p>You have received a formal warning on your <strong>Blogger Manager</strong> account.</p>
        <table style="width:100%;border-collapse:collapse;background:#EAEAF4;border-radius:8px;margin:20px 0;padding:16px;">
          <tr>
            <td style="padding:8px 16px;color:#8A80C4;font-size:13px;width:110px;">Reason</td>
            <td style="padding:8px 16px;color:#1E1A3C;font-weight:600;">${reason ?? 'No reason provided'}</td>
          </tr>
        </table>
        <p>Repeated violations of our community guidelines may result in a temporary or permanent suspension. Please review the platform rules.</p>
      ''';
    final html = _buildEmailHtml(title: 'Account Warning', recipientName: toName, bodyHtml: body);
    await _sendEmail(_warnTemplateId, _params(toEmail: toEmail, toName: toName, html: html));
    developer.log('Warning notification sent to $toEmail', name: 'EmailService');
  }

  Future<void> sendUnbanNotification({
    required String toEmail,
    required String toName,
    String? reason,
  }) async {
    final body = '''
        <p>Your <strong>Blogger Manager</strong> account suspension has been lifted. You may now log in and use the platform again.</p>
        ${(reason != null && reason != 'Your ban has been lifted. You may now log in again.') ? '''
        <table style="width:100%;border-collapse:collapse;background:#EAEAF4;border-radius:8px;margin:20px 0;padding:16px;">
          <tr>
            <td style="padding:8px 16px;color:#8A80C4;font-size:13px;width:110px;">Note</td>
            <td style="padding:8px 16px;color:#1E1A3C;font-weight:600;">$reason</td>
          </tr>
        </table>''' : ''}
      ''';
    final html = _buildEmailHtml(
      title: 'Account Reinstated',
      recipientName: toName,
      bodyHtml: body,
      ctaLabel: 'Log In Now',
      ctaUrl: 'https://bloggermanager-f1e21.web.app',
    );
    await _sendEmail(_banTemplateId, _params(toEmail: toEmail, toName: toName, html: html));
    developer.log('Unban notification sent to $toEmail', name: 'EmailService');
  }

  Map<String, dynamic> _params({
    required String toEmail,
    required String toName,
    required String html,
  }) {
    return {
      'to_email': toEmail,
      'to_name': toName,
      'name': toName,
      'from_name': 'Blogger Manager',
      'reply_to': 'noreply@bloggermanager.com',
      'html_content': html,
    };
  }

  Future<void> _sendEmail(String templateId, Map<String, dynamic> templateParams) async {
    final toEmail = templateParams['to_email'] as String? ?? '';
    if (toEmail.isEmpty) {
      throw Exception('Cannot send email: recipient email address is empty.');
    }
    developer.log('Sending email via EmailJS to: $toEmail (template: $templateId)', name: 'EmailService');

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

    developer.log('EmailJS response ${response.statusCode}: ${response.body}', name: 'EmailService');

    if (response.statusCode != 200) {
      throw Exception('EmailJS error ${response.statusCode}: ${response.body}');
    }
  }

  static String _buildEmailHtml({
    required String title,
    required String recipientName,
    required String bodyHtml,
    String? ctaLabel,
    String? ctaUrl,
  }) {
    final cta = (ctaLabel != null && ctaUrl != null)
        ? '''<div style="text-align:center;margin:28px 0;">
               <a href="$ctaUrl" style="background:#7B68C8;color:#ffffff;text-decoration:none;padding:13px 32px;border-radius:8px;font-size:15px;font-weight:600;display:inline-block;letter-spacing:0.3px;">$ctaLabel</a>
             </div>'''
        : '';

    return '''<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#EAEAF4;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#EAEAF4;padding:40px 0;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 6px 32px rgba(30,26,60,0.13);">
        <tr>
          <td style="background:#7B68C8;padding:22px 32px;text-align:center;">
            <span style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:0.8px;">Blogger Manager</span>
          </td>
        </tr>
        <tr>
          <td style="background:#DAD7FD;padding:14px 32px;">
            <span style="color:#3D2E8A;font-size:17px;font-weight:600;">$title</span>
          </td>
        </tr>
        <tr>
          <td style="padding:28px 32px 8px 32px;color:#1E1A3C;font-size:15px;line-height:1.65;">
            <p style="margin:0 0 14px 0;">Hi <strong>$recipientName</strong>,</p>
            $bodyHtml
            $cta
          </td>
        </tr>
        <tr>
          <td style="background:#EAEAF4;padding:16px 32px;text-align:center;border-top:1px solid #DAD7FD;">
            <span style="color:#8A80C4;font-size:12px;">This is an automated message from Blogger Manager. Please do not reply.</span>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>''';
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
