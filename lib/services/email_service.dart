import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Service for sending emails via Resend API
///
/// Resend free tier: 100 emails/day, 3,000 emails/month
/// Sign up at https://resend.com to get an API key
class EmailService {
  static const String _resendApiUrl = 'https://api.resend.com/emails';

  /// Send dealer invitation email
  ///
  /// Returns true if email was sent successfully, false otherwise
  static Future<bool> sendInvitationEmail({
    required String toEmail,
    required String clubName,
    required String clubId,
    required String invitationId,
    required String inviterName,
  }) async {
    final apiKey = EnvConfig.resendApiKey;
    if (apiKey.isEmpty) {
      print('EmailService: Resend API key not configured');
      return false;
    }

    final deepLink = 'pkr://invite/$clubId/$invitationId';

    final emailBody = _buildInvitationEmailHtml(
      clubName: clubName,
      inviterName: inviterName,
      deepLink: deepLink,
    );

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Poker Friend <invites@pokerfriend.app>',
          'to': [toEmail],
          'subject': 'Dealer Invitation: $clubName',
          'html': emailBody,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('EmailService: Invitation email sent to $toEmail');
        return true;
      } else {
        print('EmailService: Failed to send email - ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('EmailService: Error sending email - $e');
      return false;
    }
  }

  /// Build styled HTML email for dealer invitation
  static String _buildInvitationEmailHtml({
    required String clubName,
    required String inviterName,
    required String deepLink,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dealer Invitation</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0f0f1a;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0f0f1a;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" width="100%" style="max-width: 500px; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 20px; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="padding: 32px 32px 0;">
              <table role="presentation" width="100%">
                <tr>
                  <td>
                    <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #a855f7 0%, #7c3aed 100%); border-radius: 12px; display: inline-block; text-align: center; line-height: 50px;">
                      <span style="font-size: 24px;">&#9824;</span>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Title -->
          <tr>
            <td style="padding: 24px 32px 8px;">
              <h1 style="margin: 0; color: #a855f7; font-size: 28px; font-weight: 700;">Dealer Invitation</h1>
            </td>
          </tr>

          <!-- Inviter Info -->
          <tr>
            <td style="padding: 0 32px 24px;">
              <p style="margin: 0; color: #6b7280; font-size: 14px;">From $inviterName</p>
            </td>
          </tr>

          <!-- Main Message -->
          <tr>
            <td style="padding: 0 32px 32px;">
              <p style="margin: 0; color: #ffffff; font-size: 18px; line-height: 1.6;">
                You've been invited to join <strong style="color: #a855f7;">$clubName</strong> as a dealer.
              </p>
            </td>
          </tr>

          <!-- CTA Button -->
          <tr>
            <td style="padding: 0 32px 32px;">
              <a href="$deepLink" style="display: inline-block; background: linear-gradient(135deg, #a855f7 0%, #7c3aed 100%); color: #ffffff; padding: 16px 32px; border-radius: 12px; text-decoration: none; font-weight: 600; font-size: 16px;">
                Accept Invitation
              </a>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding: 0 32px;">
              <hr style="border: none; border-top: 1px solid #374151; margin: 0;">
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 32px 32px;">
              <p style="margin: 0; color: #6b7280; font-size: 12px; line-height: 1.6;">
                If the button doesn't work, open the Poker Logger app and check your invitations in the menu.
              </p>
              <p style="margin: 16px 0 0; color: #4b5563; font-size: 11px;">
                Sent by Poker Logger
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
