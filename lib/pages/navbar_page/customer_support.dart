import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerSupportPage extends StatelessWidget {
  const CustomerSupportPage({Key? key}) : super(key: key);

  // Phone numbers
  static const String phoneNumberSupport = '+1234567890';
  static const String phoneNumberTechnical = '+1234567891';
  static const String emailSupport = 'support@yourcompany.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text(
          'Customer Support',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  Icon(Icons.headset_mic, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    'We\'re Here to Help!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get in touch with our support team for any questions or assistance',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Contact Options
            Text(
              'Contact Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // Phone Support Card
            _buildContactCard(
              icon: Icons.phone,
              title: 'Phone Support',
              subtitle: 'Speak directly with our support team',
              details: phoneNumberSupport,
              onTap: () => _launchPhone(phoneNumberSupport),
              color: Colors.blue,
            ),

            const SizedBox(height: 16),

            // Technical Support Card
            _buildContactCard(
              icon: Icons.build,
              title: 'Technical Support',
              subtitle: 'Get help with technical issues',
              details: phoneNumberTechnical,
              onTap: () => _launchPhone(phoneNumberTechnical),
              color: Colors.blue.shade700,
            ),

            const SizedBox(height: 16),

            // Email Support Card
            _buildContactCard(
              icon: Icons.email,
              title: 'Email Support',
              subtitle: 'Send us your questions via email',
              details: emailSupport,
              onTap: () => _launchEmail(emailSupport),
              color: Colors.blue.shade600,
            ),

            const SizedBox(height: 32),

            // Support Hours
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Support Hours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSupportHour('Monday - Friday', '9:00 AM - 6:00 PM'),
                  _buildSupportHour('Saturday', '10:00 AM - 4:00 PM'),
                  _buildSupportHour('Sunday', 'Closed'),
                  const SizedBox(height: 8),
                  Text(
                    'All times are in your local timezone',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Emergency Support
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.emergency, color: Colors.red.shade600, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Emergency Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For urgent issues outside business hours, please call our emergency line',
                    style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String details,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportHour(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            hours,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Launch phone dialer
  Future<void> _launchPhone(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch phone dialer';
      }
    } catch (e) {
      debugPrint('Error launching phone: $e');
    }
  }

  // Launch email client with fallback options
  Future<void> _launchEmail(String email) async {
    // Try different email URI formats for better compatibility
    final List<Uri> emailUris = [
      // Method 1: Standard mailto with query parameters
      Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': 'Support Request',
          'body': 'Hi, I need help with...',
        },
      ),
      // Method 2: Simple mailto without parameters
      Uri(scheme: 'mailto', path: email),
      // Method 3: mailto as string
      Uri.parse('mailto:$email'),
    ];

    bool launched = false;

    for (final emailUri in emailUris) {
      try {
        debugPrint('Trying to launch: $emailUri');
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(
            emailUri,
            mode: LaunchMode.externalApplication, // Force external app
          );
          launched = true;
          break;
        }
      } catch (e) {
        debugPrint('Failed with URI $emailUri: $e');
        continue;
      }
    }

    if (!launched) {
      debugPrint('All email launch methods failed');
      // Show a snackbar or dialog to inform user
      _showEmailFallback(email);
    }
  }

  // Fallback method to show email address for manual copy
  void _showEmailFallback(String email) {
    // You can implement this to show a dialog or snackbar
    debugPrint('Email fallback: $email');
  }
}

// Usage example in your main app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Support App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CustomerSupportPage(),
    );
  }
}
