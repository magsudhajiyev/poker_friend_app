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
          'from': 'Final Table <invites@finaltable.io>',
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

  /// Send new club request notification email to app admins
  static Future<bool> sendNewClubRequestEmail({
    required String toEmail,
    required String clubName,
    required String requesterName,
    required String requesterEmail,
    String? address,
    String? phone,
  }) async {
    final apiKey = EnvConfig.resendApiKey;
    if (apiKey.isEmpty) {
      print('EmailService: Resend API key not configured');
      return false;
    }

    final emailBody = _buildNewClubRequestEmailHtml(
      clubName: clubName,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      address: address,
      phone: phone,
    );

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Final Table <admin@finaltable.io>',
          'to': [toEmail],
          'subject': 'New Club Request: $clubName',
          'html': emailBody,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('EmailService: New club request email sent to $toEmail');
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

  /// Build styled HTML email for new club request notification
  static String _buildNewClubRequestEmailHtml({
    required String clubName,
    required String requesterName,
    required String requesterEmail,
    String? address,
    String? phone,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New Club Request</title>
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
                    <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); border-radius: 12px; display: inline-block; text-align: center; line-height: 50px;">
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
              <h1 style="margin: 0; color: #f59e0b; font-size: 28px; font-weight: 700;">New Club Request</h1>
            </td>
          </tr>

          <!-- Main Message -->
          <tr>
            <td style="padding: 16px 32px 32px;">
              <p style="margin: 0; color: #ffffff; font-size: 18px; line-height: 1.6;">
                A new club registration request has been submitted.
              </p>
              <table role="presentation" style="margin-top: 24px; width: 100%;">
                <tr>
                  <td style="padding: 8px 0; color: #9ca3af; font-size: 14px;">Club Name:</td>
                  <td style="padding: 8px 0; color: #ffffff; font-size: 14px; font-weight: 600;">$clubName</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #9ca3af; font-size: 14px;">Requested By:</td>
                  <td style="padding: 8px 0; color: #ffffff; font-size: 14px;">$requesterName</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #9ca3af; font-size: 14px;">Email:</td>
                  <td style="padding: 8px 0; color: #ffffff; font-size: 14px;">$requesterEmail</td>
                </tr>
                ${address != null && address.isNotEmpty ? '''
                <tr>
                  <td style="padding: 8px 0; color: #9ca3af; font-size: 14px;">Address:</td>
                  <td style="padding: 8px 0; color: #ffffff; font-size: 14px;">$address</td>
                </tr>
                ''' : ''}
                ${phone != null && phone.isNotEmpty ? '''
                <tr>
                  <td style="padding: 8px 0; color: #9ca3af; font-size: 14px;">Phone:</td>
                  <td style="padding: 8px 0; color: #ffffff; font-size: 14px;">$phone</td>
                </tr>
                ''' : ''}
              </table>
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
                Open the Final Table app to review this request.
              </p>
              <p style="margin: 16px 0 0; color: #4b5563; font-size: 11px;">
                Sent by Final Table Admin System
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

  /// Send club approval notification email
  static Future<bool> sendClubApprovalEmail({
    required String toEmail,
    required String clubName,
  }) async {
    final apiKey = EnvConfig.resendApiKey;
    if (apiKey.isEmpty) {
      print('EmailService: Resend API key not configured');
      return false;
    }

    final emailBody = _buildClubApprovalEmailHtml(clubName: clubName);

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Final Table <clubs@finaltable.io>',
          'to': [toEmail],
          'subject': 'Your Club Has Been Approved: $clubName',
          'html': emailBody,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('EmailService: Club approval email sent to $toEmail');
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

  /// Build styled HTML email for club approval
  static String _buildClubApprovalEmailHtml({
    required String clubName,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Club Approved</title>
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
                    <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); border-radius: 12px; display: inline-block; text-align: center; line-height: 50px;">
                      <span style="font-size: 24px;">&#10003;</span>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Title -->
          <tr>
            <td style="padding: 24px 32px 8px;">
              <h1 style="margin: 0; color: #22c55e; font-size: 28px; font-weight: 700;">Club Approved!</h1>
            </td>
          </tr>

          <!-- Main Message -->
          <tr>
            <td style="padding: 16px 32px 32px;">
              <p style="margin: 0; color: #ffffff; font-size: 18px; line-height: 1.6;">
                Great news! Your club <strong style="color: #22c55e;">$clubName</strong> has been approved and is now ready to use.
              </p>
              <p style="margin: 24px 0 0; color: #9ca3af; font-size: 16px; line-height: 1.6;">
                You can now log in to Final Table and start managing your club, adding tables, inviting dealers, and hosting events.
              </p>
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
                Open the Final Table app to get started with your new club.
              </p>
              <p style="margin: 16px 0 0; color: #4b5563; font-size: 11px;">
                Sent by Final Table
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

  /// Send member/admin invitation email
  static Future<bool> sendMemberInvitationEmail({
    required String toEmail,
    required String clubName,
    required String inviterName,
    required String role,  // 'dealer' or 'admin'
  }) async {
    final apiKey = EnvConfig.resendApiKey;
    if (apiKey.isEmpty) {
      print('EmailService: Resend API key not configured');
      return false;
    }

    final emailBody = _buildMemberInvitationEmailHtml(
      clubName: clubName,
      inviterName: inviterName,
      role: role,
    );

    final roleTitle = role == 'admin' ? 'Admin' : 'Dealer';

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Final Table <invites@finaltable.io>',
          'to': [toEmail],
          'subject': '$roleTitle Invitation: $clubName',
          'html': emailBody,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('EmailService: Member invitation email sent to $toEmail');
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

  /// Build styled HTML email for member invitation
  static String _buildMemberInvitationEmailHtml({
    required String clubName,
    required String inviterName,
    required String role,
  }) {
    final roleTitle = role == 'admin' ? 'an Admin' : 'a Dealer';
    final roleColor = role == 'admin' ? '#f59e0b' : '#a855f7';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Club Invitation</title>
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
                    <div style="width: 50px; height: 50px; background: linear-gradient(135deg, $roleColor 0%, ${role == 'admin' ? '#d97706' : '#7c3aed'} 100%); border-radius: 12px; display: inline-block; text-align: center; line-height: 50px;">
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
              <h1 style="margin: 0; color: $roleColor; font-size: 28px; font-weight: 700;">You're Invited!</h1>
            </td>
          </tr>

          <!-- Inviter Info -->
          <tr>
            <td style="padding: 0 32px 24px;">
              <p style="margin: 0; color: #6b7280; font-size: 14px;">Invitation from $inviterName</p>
            </td>
          </tr>

          <!-- Main Message -->
          <tr>
            <td style="padding: 0 32px 32px;">
              <p style="margin: 0; color: #ffffff; font-size: 18px; line-height: 1.6;">
                You've been invited to join <strong style="color: $roleColor;">$clubName</strong> as $roleTitle.
              </p>
              <p style="margin: 16px 0 0; color: #9ca3af; font-size: 16px; line-height: 1.6;">
                Open the Final Table app to accept this invitation and start ${role == 'admin' ? 'managing' : 'dealing at'} the club.
              </p>
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
                If you don't have the app yet, download Final Table from the App Store or Google Play.
              </p>
              <p style="margin: 16px 0 0; color: #4b5563; font-size: 11px;">
                Sent by Final Table
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
                If the button doesn't work, open the Final Table app and check your invitations in the menu.
              </p>
              <p style="margin: 16px 0 0; color: #4b5563; font-size: 11px;">
                Sent by Final Table
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

  /// Send password reset verification code email
  static Future<bool> sendPasswordResetCodeEmail({
    required String toEmail,
    required String code,
  }) async {
    final apiKey = EnvConfig.resendApiKey;
    if (apiKey.isEmpty) {
      print('EmailService: Resend API key not configured');
      return false;
    }

    final emailBody = _buildPasswordResetCodeEmailHtml(code: code);

    try {
      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Final Table <noreply@finaltable.io>',
          'to': [toEmail],
          'subject': 'Password Reset Code: $code',
          'html': emailBody,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('EmailService: Password reset code sent to $toEmail');
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

  /// Build styled HTML email for password reset code
  static String _buildPasswordResetCodeEmailHtml({required String code}) {
    // Split code into individual digits for styled display
    final digits = code.split('');
    final digitCells = digits.map((d) =>
      '<td style="width: 48px; height: 56px; background-color: #1e293b; border-radius: 12px; text-align: center; vertical-align: middle; border: 1px solid #374151;">'
      '<span style="color: #62E3BC; font-size: 28px; font-weight: 700; font-family: monospace;">$d</span>'
      '</td>'
    ).join('<td style="width: 8px;"></td>');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Password Reset Code</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0f0f1a;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0f0f1a;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" width="100%" style="max-width: 500px; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 20px; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="padding: 32px 32px 0;">
              <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #62E3BC 0%, #89F1EC 100%); border-radius: 12px; display: inline-block; text-align: center; line-height: 50px;">
                <span style="font-size: 24px; color: #0f0f1a;">&#9824;</span>
              </div>
            </td>
          </tr>

          <!-- Title -->
          <tr>
            <td style="padding: 24px 32px 8px;">
              <h1 style="margin: 0; color: #62E3BC; font-size: 28px; font-weight: 700;">Password Reset</h1>
            </td>
          </tr>

          <!-- Message -->
          <tr>
            <td style="padding: 16px 32px 8px;">
              <p style="margin: 0; color: #e2e8f0; font-size: 16px; line-height: 1.6;">
                Use the following code to reset your password:
              </p>
            </td>
          </tr>

          <!-- Code Display -->
          <tr>
            <td style="padding: 24px 32px;">
              <table role="presentation" cellspacing="0" cellpadding="0" style="margin: 0 auto;">
                <tr>$digitCells</tr>
              </table>
            </td>
          </tr>

          <!-- Expiry Note -->
          <tr>
            <td style="padding: 0 32px 32px;">
              <p style="margin: 0; color: #9ca3af; font-size: 14px; text-align: center;">
                This code expires in <strong style="color: #e2e8f0;">15 minutes</strong>.
              </p>
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
                If you didn't request a password reset, you can safely ignore this email.
              </p>
              <p style="margin: 16px 0 0; color: #4b5563; font-size: 11px;">
                Sent by Final Table
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
