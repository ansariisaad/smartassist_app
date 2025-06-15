import 'dart:convert';

import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/home_screen.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/button.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/license_varification.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class TestdriveVerifyotp extends StatefulWidget {
  static const int _otpLength = 6;
  final String eventId;
  final String leadId;
  final String email;
  final String mobile;
  final TextStyle? style;

  const TestdriveVerifyotp({
    super.key,
    required this.email,
    this.style,
    required this.eventId,
    required this.leadId,
    required this.mobile,
  });

  @override
  State<TestdriveVerifyotp> createState() => _TestdriveVerifyotpState();
}

class _TestdriveVerifyotpState extends State<TestdriveVerifyotp> {
  final List<TextEditingController> _controllers = List.generate(
    TestdriveVerifyotp._otpLength,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    TestdriveVerifyotp._otpLength,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResendingOTP = false;
  int _resendTimer = 30;

  // exit popup
  DateTime? _lastBackPressTime;
  final int _exitTimeInMillis = 2000;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() => _resendTimer--);
        _startResendTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Center(
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeaderImage(),
                    _buildTitle(),
                    _buildEmailInfo(),
                    const SizedBox(height: 20),
                    _buildOTPFields(),
                    const SizedBox(height: 20),
                    _buildResendOption(),
                    Row(
                      children: [
                        Expanded(child: _cancelButton()),
                        Expanded(child: _buildVerifyButton()),
                        // _buildVerifyButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Image.asset('assets/car.png', width: 150, fit: BoxFit.contain),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text('Start Test drive', style: AppFont.popupTitle(context)),
    );
  }

  // Widget _buildEmailInfo() {
  //   return Padding(

  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
  //     child: Text(
  //       textAlign: TextAlign.center,
  //       'Enter OTP sent to ${widget.email} to continue',
  //       style: AppFont.mediumText14(context),
  //     ),
  //   );
  // }
  Widget _buildEmailInfo() {
    bool isEmailHidden = true;
    String mobile = widget.mobile;
    String emailPart = widget.email;

    String hiddenMobile = _hideMobileNumber(mobile);
    String hiddenEmail = _hideEmail(emailPart);

    String message =
        'Enter OTP sent to $hiddenMobile & ${isEmailHidden ? hiddenEmail : emailPart} to continue';

    return Text(
      message,
      textAlign: TextAlign.center,
      style: AppFont.mediumText14(context),
    );
  }

  // Helper to hide mobile number
  String _hideMobileNumber(String mobile) {
    if (mobile.length >= 10) {
      // Example: 98765XXXXX
      return mobile.substring(0, 3) + '*****' + mobile.substring(8);
    } else {
      return mobile; // fallback
    }
  }

  // Helper to hide email
  String _hideEmail(String email) {
    if (!email.contains('@')) return email; // invalid email fallback

    List<String> parts = email.split('@');
    String namePart = parts[0];
    String domainPart = parts[1];

    if (namePart.length <= 2) {
      return '***@$domainPart'; // too short, hide full
    } else {
      String visible = namePart.substring(0, 2); // first 2 letters
      return '$visible***@$domainPart';
    }
  }

  Widget _buildOTPFields() {
    // Calculate the available width for OTP fields
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // Subtract horizontal padding
    final spacing = 8.0;
    // Calculate field width based on available space
    final fieldWidth =
        (availableWidth - (spacing * (TestdriveVerifyotp._otpLength - 1))) /
        TestdriveVerifyotp._otpLength;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            TestdriveVerifyotp._otpLength,
            (index) => Container(
              margin: EdgeInsets.only(
                right: index < TestdriveVerifyotp._otpLength - 1 ? spacing : 0,
              ),
              width: fieldWidth.clamp(35, 45),
              height: 50,
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                onChanged: (value) => _handleOTPInput(value, index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendOption() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        text: "Didn't receive the code? ",
        style: AppFont.mediumText14(context),
        children: [
          TextSpan(
            text: _resendTimer > 0 ? 'Resend in ${_resendTimer}s' : 'Resend',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _resendTimer > 0 ? Colors.grey : AppColors.colorsBlue,
              decoration: _resendTimer > 0 ? null : TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = _resendTimer > 0 ? null : _handleResendOTP,
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 8),
      child: ElevatedButton(
        onPressed: () async {
          // Navigator.push(
          //     context,
          //     MaterialPageRoute(
          //       builder: (context) => LicenseVarification(
          //         eventId: widget.eventId,
          //         leadId: widget.leadId,
          //       ),
          //     ));
          await _handleVerification();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0276FE),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Button(
                'Verify',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _cancelButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 8),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.containerPopBg,
          foregroundColor: AppColors.fontColor,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Button(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _handleOTPInput(String value, int index) {
    if (value.isNotEmpty && index < TestdriveVerifyotp._otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleResendOTP() async {
    if (_isResendingOTP) return;

    setState(() => _isResendingOTP = true);

    try {
      // Implement your resend OTP logic here
      // await OtpSrv.resendOTP({"email": widget.email});

      if (!mounted) return;

      setState(() => _resendTimer = 30);
      _startResendTimer();

      showSuccessMessage(context, message: 'OTP resent successfully');
    } catch (error) {
      if (!mounted) return;
      showErrorMessage(context, message: 'Failed to resend OTP');
      debugPrint('Resend OTP error: $error');
    } finally {
      if (mounted) {
        setState(() => _isResendingOTP = false);
      }
    }
  }

  Future<void> _handleVerification() async {
    final otpString = _controllers.map((controller) => controller.text).join();

    if (otpString.length != TestdriveVerifyotp._otpLength) {
      showErrorMessage(context, message: 'Please enter all digits');
      return;
    }

    if (int.tryParse(otpString) == null) {
      showErrorMessage(context, message: 'Please enter valid digits');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://api.smartassistapp.in/api/events/${widget.eventId}/verify-otp',
      );
      final token = await Storage.getToken();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"otp": int.parse(otpString)}),
      );

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      print(response.body);

      if (response.statusCode == 200) {
        final successMessage =
            decoded['message'] ?? 'OTP verified successfully';
        showSuccessMessage(context, message: successMessage);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LicenseVarification(
              eventId: widget.eventId,
              leadId: widget.leadId,
            ),
          ),
        );
      } else {
        final errorMessage =
            decoded['message'] ?? 'Invalid OTP. Please try again.';
        showErrorMessage(context, message: errorMessage);
      }
    } catch (error) {
      if (!mounted) return;
      showErrorMessage(
        context,
        message: 'Verification failed. Please try again.',
      );
      debugPrint('OTP verification error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // _handleVerification() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => PassportVarification(eventId: widget.eventId),
  //     ),
  //   );
  // }

  // void _navigateToPasswordScreen() {
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => PassportVarification(eventId: widget.eventId),
  //     ),
  //   );
  // }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) >
            Duration(milliseconds: _exitTimeInMillis)) {
      _lastBackPressTime = now;

      // Show a bottom slide dialog
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Exit Test',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorsBlue,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to exit?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Cancel button (White)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Dismiss dialog
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.colorsBlue,
                            side: const BorderSide(color: AppColors.colorsBlue),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Exit button (Blue) - Modified to navigate to HomeScreen
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Clear all routes and navigate to HomeScreen
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => BottomNavigation(),

                                // HomeScreen(greeting: '', leadId: '')
                              ),
                              (route) => false, // This clears the stack
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.colorsBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Exit',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          );
        },
      );
      return false;
    }
    return true;
  }
}
