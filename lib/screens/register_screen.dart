import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailOtpController = TextEditingController();
  final _phoneOtpController = TextEditingController();

  String _selectedCountryCode = '+91';
  final Map<String, String> _countryLabels = {
    '+91': '🇮🇳 +91',
    '+1': '🇺🇸 +1',
    '+44': '🇬🇧 +44',
    '+971': '🇦🇪 +971',
    '+61': '🇦🇺 +61',
    '+65': '🇸🇬 +65',
    '+81': '🇯🇵 +81',
    '+49': '🇩🇪 +49',
    '+33': '🇫🇷 +33',
  };

  bool _isEmailOtpSent = false;
  bool _isEmailVerified = false;
  bool _isPhoneOtpSent = false;
  bool _isPhoneVerified = false;

  Future<void> _sendEmailOtp() async {
    final emailText = _emailController.text.trim();
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (emailText.isEmpty || !emailRegExp.hasMatch(emailText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address first')),
      );
      return;
    }

    final code = await Provider.of<AppState>(context, listen: false).sendOtp('email', emailText);
    if (!mounted) return;
    if (code != null) {
      setState(() {
        _isEmailOtpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP Sent! For testing, your code is: $code'),
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Copy',
            textColor: Colors.greenAccent,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send OTP to email.')),
      );
    }
  }

  Future<void> _verifyEmailOtp() async {
    final emailText = _emailController.text.trim();
    final otpCode = _emailOtpController.text.trim();
    if (otpCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP code')),
      );
      return;
    }

    final verified = await Provider.of<AppState>(context, listen: false).verifyOtp(emailText, otpCode);
    if (!mounted) return;
    if (verified) {
      setState(() {
        _isEmailVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification code. Please try again.')),
      );
    }
  }

  Future<void> _sendPhoneOtp() async {
    final phoneText = _phoneController.text.trim();
    if (phoneText.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number first')),
      );
      return;
    }

    final fullPhone = '$_selectedCountryCode$phoneText';
    final code = await Provider.of<AppState>(context, listen: false).sendOtp('phone', fullPhone);
    if (!mounted) return;
    if (code != null) {
      setState(() {
        _isPhoneOtpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP Sent! For testing, your code is: $code'),
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Copy',
            textColor: Colors.greenAccent,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send OTP to phone.')),
      );
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final phoneText = _phoneController.text.trim();
    final fullPhone = '$_selectedCountryCode$phoneText';
    final otpCode = _phoneOtpController.text.trim();
    if (otpCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP code')),
      );
      return;
    }

    final verified = await Provider.of<AppState>(context, listen: false).verifyOtp(fullPhone, otpCode);
    if (!mounted) return;
    if (verified) {
      setState(() {
        _isPhoneVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number verified successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification code. Please try again.')),
      );
    }
  }

  Future<void> _register() async {
    final nameText = _nameController.text.trim();
    final emailText = _emailController.text.trim();
    final phoneText = _phoneController.text.trim();
    final passwordText = _passwordController.text;

    if (nameText.isEmpty || emailText.isEmpty || phoneText.isEmpty || passwordText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    // Verify OTP locks
    if (!_isEmailVerified || !_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify both your email and phone number using OTP first.')),
      );
      return;
    }

    final fullPhone = '$_selectedCountryCode$phoneText';

    final success = await Provider.of<AppState>(context, listen: false).registerUser(
      nameText,
      emailText,
      fullPhone,
      passwordText,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please log in.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email or Phone is already registered.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create an Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 24),
              const Text('Join Split-Buddy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Full Name'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      enabled: !_isEmailVerified,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Email Address'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isEmailVerified)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Verified', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _sendEmailOtp,
                      child: Text(_isEmailOtpSent ? 'Resend' : 'Verify'),
                    ),
                ],
              ),
              if (_isEmailOtpSent && !_isEmailVerified) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailOtpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Enter 6-digit Email OTP',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _verifyEmailOtp,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        onChanged: _isPhoneVerified ? null : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCountryCode = val;
                            });
                          }
                        },
                        items: _countryLabels.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      enabled: !_isPhoneVerified,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Phone Number',
                        hintText: '10-digit number',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isPhoneVerified)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Verified', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _sendPhoneOtp,
                      child: Text(_isPhoneOtpSent ? 'Resend' : 'Verify'),
                    ),
                ],
              ),
              if (_isPhoneOtpSent && !_isPhoneVerified) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneOtpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Enter 6-digit Phone OTP',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _verifyPhoneOtp,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Password'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('Sign Up', style: TextStyle(fontSize: 18)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('Already have an account? Log in here.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
