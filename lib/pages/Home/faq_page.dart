import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  int? expandedIndex;

  final List<Map<String, String>> faqData = [
    {
      'question': 'What is SmartAssist?',
      'answer':
          'SmartAssist is an intelligent assistant application designed to help you with various tasks and provide quick solutions to your everyday needs.',
    },
    {
      'question': 'How do I get started?',
      'answer':
          'Simply download the app, create an account, and follow the guided setup process. You\'ll be ready to use SmartAssist within minutes.',
    },
    {
      'question': 'Is my data secure?',
      'answer':
          'Yes, we take data security very seriously. All your information is encrypted and stored securely. We never share your personal data with third parties without your consent.',
    },
    {
      'question': 'How can I contact support?',
      'answer':
          'You can reach our support team through the in-app chat feature, email us at support@smartassist.com, or visit our help center for instant solutions.',
    },
    {
      'question': 'Is there a premium version?',
      'answer':
          'Yes, SmartAssist Pro offers additional features including advanced AI capabilities, priority support, and unlimited usage. Check the pricing section for more details.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(FontAwesomeIcons.angleLeft, color: Colors.white),
        ),
        title: Text(
          'Frequently Asked Questions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.colorsBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.colorsBlue,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              children: [
                const Icon(
                  FontAwesomeIcons.circleQuestion,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'How can we help you?',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find answers to common questions below',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // FAQ List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: faqData.length,
              itemBuilder: (context, index) {
                final isExpanded = expandedIndex == index;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: isExpanded
                          ? AppColors.colorsBlue
                          : Colors.grey.withOpacity(0.2),
                      width: isExpanded ? 1.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          20,
                        ),
                        backgroundColor: Colors.white,
                        collapsedBackgroundColor: Colors.white,
                        iconColor: AppColors.colorsBlue,
                        collapsedIconColor: Colors.grey.shade600,
                        // Remove grey ripple effect
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        collapsedShape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        onExpansionChanged: (expanded) {
                          setState(() {
                            expandedIndex = expanded ? index : null;
                          });
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AppColors.colorsBlue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            FontAwesomeIcons.circleQuestion,
                            color: isExpanded
                                ? AppColors.colorsBlue
                                : Colors.grey.shade600,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          faqData[index]['question']!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isExpanded
                                ? AppColors.colorsBlue
                                : Colors.grey.shade800,
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              faqData[index]['answer']!,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
