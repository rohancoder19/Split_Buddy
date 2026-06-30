import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import 'register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _logoPulseController;
  late Animation<double> _logoPulseAnimation;

  Timer? _elapsedTimer;
  int _secondsElapsed = 0;
  String _statusMessage = 'Connecting to Split-Buddy...';
  bool _hasError = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();

    // Setup pulsing animation for logo
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _logoPulseAnimation = CurvedAnimation(
      parent: _logoPulseController,
      curve: Curves.easeInOut,
    );

    // Start elapsed timer
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
          _updateStatusMessage();
        });
      }
    });

    // Start server connectivity check
    _checkServerStatus();
  }

  void _updateStatusMessage() {
    if (_secondsElapsed < 6) {
      _statusMessage = 'Connecting to Split-Buddy...';
    } else if (_secondsElapsed < 15) {
      _statusMessage = 'Waking up cloud server instance...';
    } else if (_secondsElapsed < 30) {
      _statusMessage = 'Server is booting up. Thank you for waiting...';
    } else if (_secondsElapsed < 50) {
      _statusMessage = 'Almost there! Connecting database...';
    } else {
      _statusMessage = 'Waking up is taking a bit longer. Thank you for your patience...';
    }
  }

  Future<void> _checkServerStatus() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _hasError = false;
    });

    const int maxRetries = 15;
    const Duration delayBetweenRetries = Duration(seconds: 6);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (!mounted) return;

      try {
        debugPrint('[Splash] Attempt $attempt to connect to backend...');
        final config = await ApiService().getConfig();
        
        if (config.isNotEmpty) {
          debugPrint('[Splash] Backend responded successfully! Config loaded.');
          
          // Trigger config load on AppState as well so its API key is set
          if (mounted) {
            await Provider.of<AppState>(context, listen: false).loadConfig();
          }

          if (!mounted) return;

          // Transition smoothly to Register Screen
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const RegisterScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('[Splash] Attempt $attempt failed with error: $e');
      }

      // Wait before the next attempt
      await Future.delayed(delayBetweenRetries);
    }

    // If we exit the loop, we exceeded the retries without success
    if (mounted) {
      setState(() {
        _hasError = true;
        _isChecking = false;
      });
    }
  }

  @override
  void dispose() {
    _logoPulseController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E9), // Mint green highlight
              Color(0xFFE0F2F1), // Soft teal
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated Pulsing Logo
              AnimatedBuilder(
                animation: _logoPulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_logoPulseAnimation.value * 0.08),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.25 * _logoPulseAnimation.value),
                            blurRadius: 25 + (_logoPulseAnimation.value * 25),
                            spreadRadius: 6 + (_logoPulseAnimation.value * 6),
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback icon in case logo is missing
                                return Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 60,
                                  color: primaryColor,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 36),

              // Title and Subtitle
              Text(
                'Split-Buddy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryColor.withRed(30).withGreen(100).withBlue(90), // darker shade
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Smart Split AI & Expense Tracker',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(flex: 1),

              // Status Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _hasError
                      ? _buildErrorState(primaryColor)
                      : _buildLoadingState(primaryColor),
                ),
              ),

              const Spacer(flex: 2),

              // Version / Branding Text
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'v1.0.0 • Travel Better. Settled Together.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Column(
      key: const ValueKey('loading_state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Custom progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            backgroundColor: primaryColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time elapsed: ${_secondsElapsed}s',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Status: Warming up',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const Divider(height: 28),

        // Information banner explaining render sleep cycle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_queue,
                color: primaryColor.withRed(30).withGreen(120),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'To keep our service free, our cloud servers sleep when inactive. Waking them up takes about a minute. Thank you for your patience!',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Color primaryColor) {
    return Column(
      key: const ValueKey('error_state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Unable to Connect',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'We couldn\'t reach the server.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Please verify your internet connection or try again. The server might be taking slightly longer to boot.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _checkServerStatus,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
