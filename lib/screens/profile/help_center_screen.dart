import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_container.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  // Track expanded FAQs
  final Set<int> _expandedFaqs = {};

  // List of FAQs
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I join a class?',
      'answer':
          'To join a class, go to the Classes tab and tap on the "Join Class" button. Enter the class code provided by your lecturer and tap "Join".',
    },
    {
      'question': 'How do I create a new class?',
      'answer':
          'As a lecturer, you can create a new class by going to the Classes tab and tapping on the "Create Class" button. Fill in the class details and tap "Create".',
    },
    {
      'question': 'How can I download resources?',
      'answer':
          'Navigate to the Resources tab, find the resource you want to download, and tap the download icon next to it. Once downloaded, you can tap on it to open.',
    },
    {
      'question': 'How do I change the app theme?',
      'answer':
          'Go to Profile > Preferences and select your preferred theme: Light, Dark, or System.',
    },
    {
      'question': 'How do I update my profile information?',
      'answer':
          'Go to Profile > Account > Edit Profile. Update your information and tap "Save Changes".',
    },
    {
      'question': 'Can I use the app offline?',
      'answer':
          'Yes, many features work offline. Resources and classes you\'ve already accessed will be available offline. You\'ll need to connect to the internet to sync new data.',
    },
  ];

  void _toggleFaq(int index) {
    setState(() {
      if (_expandedFaqs.contains(index)) {
        _expandedFaqs.remove(index);
      } else {
        _expandedFaqs.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help Center',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              GradientContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 28,
                useCardStyle: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How can we help you?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find answers to frequently asked questions or contact our support team',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Contact us section
              Text(
                'Contact Us',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildContactCard(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: 'support@educonnect.edu',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildContactCard(
                icon: Icons.chat_outlined,
                title: 'Live Chat',
                subtitle: 'Available Mon-Fri, 9AM-5PM',
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // FAQ section
              Text(
                'Frequently Asked Questions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _faqs.length,
                itemBuilder: (context, index) {
                  final faq = _faqs[index];
                  final isExpanded = _expandedFaqs.contains(index);
                  return _buildFaqItem(
                    faq['question']!,
                    faq['answer']!,
                    isExpanded,
                    () => _toggleFaq(index),
                    isDark,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppTheme.darkPrimaryStart.withOpacity(0.1)
                        : AppTheme.lightPrimaryStart.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color:
                    isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color:
                          isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color:
                          isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(
    String question,
    String answer,
    bool isExpanded,
    VoidCallback onToggle,
    bool isDark,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (_) => onToggle(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          title: Text(
            question,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color:
                  isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          children: [
            Text(
              answer,
              style: GoogleFonts.inter(
                fontSize: 14,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
