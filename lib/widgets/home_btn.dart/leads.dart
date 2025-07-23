import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class Leads extends StatefulWidget {
  final Function(String) onFormSubmit;
  final Map<String, dynamic> MtdData;
  final Map<String, dynamic> YtdData;
  final Map<String, dynamic> QtdData;
  const Leads({
    super.key,
    required this.MtdData,
    required this.YtdData,
    required this.QtdData,
    required this.onFormSubmit,
  });

  @override
  State<Leads> createState() => _LeadsState();
}

class _LeadsState extends State<Leads> {
  // final selectedData = getSelectedData();

  int _childButtonIndex = 0;
  final PageController _pageController = PageController();

  Map<String, dynamic> getSelectedData() {
    // print('this is data selected');
    Map<String, dynamic> periodData;

    // Select the appropriate period data
    switch (_childButtonIndex) {
      case 1:
        periodData = widget.MtdData;
        break;
      case 0:
        periodData = widget.QtdData;
        break;
      case 2:
        periodData = widget.YtdData;
        break;
      default:
        periodData = {};
    }

    // Make sure allData exists, otherwise return empty map
    return periodData['data'] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width and height for responsiveness
    double screenWidth = MediaQuery.of(context).size.width;
    final selectedData = getSelectedData();

    return Column(
      children: [
        // Top Row with Buttons and Enquiry Bank
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Buttons Container
              Container(
                width: screenWidth * 0.45,
                height: 27,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    _buildButton('MTD', 1),
                    _buildButton('QTD', 0),
                    _buildButton('YTD', 2),
                  ],
                ),
              ),

              // Enquiry Bank Container
              Container(
                width: screenWidth * 0.42,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enquiry bank',
                      style: AppFont.smallText(
                        context,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${getSelectedData()['enquiryBank'] ?? 0}',
                      style: AppFont.smallTextBold(
                        context,
                      ).copyWith(color: AppColors.colorsBlue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // PageView for Slides
        SizedBox(
          height: 240,
          child: PageView(
            controller: _pageController,
            children: [
              _buildFirstSlide(context, screenWidth),
              _buildSecondSlide(context, screenWidth),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Smooth Page Indicator
        SmoothPageIndicator(
          controller: _pageController,
          count: 2,
          effect: WormEffect(
            activeDotColor: AppColors.colorsBlue,
            dotColor: Colors.grey.shade300,
            dotHeight: 8,
            dotWidth: 8,
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  // First Slide
  Widget _buildFirstSlide(BuildContext context, double screenWidth) {
    final selectedData = getSelectedData();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _buildInfoCard1(
                      context,
                      'Enquiries you have',
                      '${selectedData['newEnquiries'] ?? 0}',
                      screenWidth,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildInfoCard1(
                      context,
                      'Enquiries lost',
                      '${selectedData['lostEnquiries'] ?? 0}',
                      screenWidth,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRightInfoCard(
                context,
                'You must pursue',
                'more enquiries to achieve your target',
                '${selectedData['enquiriesToAchieveTarget'] ?? 0}',
                screenWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Second Slide
  Widget _buildSecondSlide(BuildContext context, double screenWidth) {
    final selectedData = getSelectedData();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    context,
                    'Follow ups recommended per lost enquiry',
                    'Follow ups done by you per lost enquiry',
                    '${selectedData['followupsPerLostEnquiry'] ?? '0'}',
                    '5',
                    // '${selectedData['enquiryBank'] ?? 0}',
                    screenWidth,
                    Colors.red,
                    Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _buildInfoCard(
                    context,
                    'Follow ups recommended per lost digital enquiry',
                    'Follow ups done by you per lost digital enquiry',
                    '${selectedData['followupsPerLostDigitalEnquiry'] ?? '0'}',
                    '5',
                    screenWidth,
                    Colors.red,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRightInfoCard2(
              context,
              'On an average, you take',
              'to convert an enquiry to order',
              '${selectedData['avgEnquiry'] ?? 0} days',
              screenWidth,
            ),
          ),
        ],
      ),
    );
  }

  // Button Builder
  Widget _buildButton(String text, int index) {
    bool isSelected = _childButtonIndex == index;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.colorsBlue : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: TextButton(
          onPressed: () async {
            setState(() {
              _childButtonIndex = index;
            });

            await widget.onFormSubmit(text);
          },
          style: TextButton.styleFrom(
            foregroundColor: isSelected ? AppColors.colorsBlue : Colors.black,
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? AppColors.colorsBlue : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title1,
    String title,
    String value,
    String value1,
    double screenWidth,
    Color valueColor,
    Color valueColor1,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                // textAlign: TextAlign.center,
                maxLines: 4,
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  softWrap: true,
                  // textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                  style: AppFont.smallText10(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                // textAlign: TextAlign.center,
                maxLines: 4,
                value1,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: valueColor1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title1,
                  softWrap: true,
                  // textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                  style: AppFont.smallText10(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Info Card for Left Columns
  Widget _buildInfoCard1(
    BuildContext context,
    String title,
    String value,
    double screenWidth,
    Color valueColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 4,
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(width: 10),
          // Using Container instead of Expanded for Title Text
          Expanded(
            child: Text(
              title,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 4,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.grey[700],
              ),
            ),
          ),
          // The value text
        ],
      ),
    );
  }

  // Right Info Card
  Widget _buildRightInfoCard(
    BuildContext context,
    String title,
    String head,
    String value,
    double screenWidth,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.colorsBlue,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            head,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightInfoCard2(
    BuildContext context,
    String title,
    String head,
    String value,
    double screenWidth,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.colorsBlue,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            head,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
