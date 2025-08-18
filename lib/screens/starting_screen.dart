import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gofi/screens/login_screen.dart';
import 'register_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Usuwa banner debugowania
      home: const StartingScreen(),
    );
  }
}

class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 844,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.white),
            child: Stack(
              children: [
                Positioned(
                  left: -2,
                  top: 0,
                  child: Container(
                    width: 392,
                    height: 611,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/image01.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 394,
                    height: 138,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0.50, -0.00),
                        end: Alignment(0.50, 1.00),
                        colors: [
                          Color(0xAF151D2C),
                          Colors.black.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 68,
                  top: 746,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            color: Color(0xFF20273B),
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: 'Sign In',
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                              );
                            },
                          style: TextStyle(
                            color: Color(0xFFFD605B),
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Positioned(
                  left: 214,
                  top: 625,
                  child: Container(
                    height: 2,
                    width: 76.84,
                    color: Colors.orange,
                  ),
                ),
                Positioned(
                  left: 101,
                  top: 625,
                  child: Container(
                    height: 2,
                    width: 76.84,
                    color: Colors.orange,
                  ),
                ),
                Positioned(
                  left: 186,
                  top: 631,
                  child: SizedBox(
                    width: 19.5,
                    height: 15,
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Color(0xFF192E65),
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 40,
                  top: 654,
                  child: Container(
                    width: 310,
                    height: 54.71,
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                      shadows: [
                        BoxShadow(
                          color: Color(0x23000000),
                          blurRadius: 26,
                          offset: Offset(0, 4),
                          spreadRadius: 0,
                        )
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 146,
                  top: 670,
                  child: SizedBox(
                    width: 144,
                    height: 23,
                    child: Text(
                      'Sign Up with Google',
                      style: TextStyle(
                        color: Color(0xFF31343D),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 25,
                  top: 548,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: Container(
                      width: 339.04,
                      height: 51.97,
                      decoration: ShapeDecoration(
                        color: Color(0xFFFD605B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                        shadows: [
                          BoxShadow(
                            color: Color(0x33FD605B),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                            spreadRadius: 0,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            height: 1.38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 25,
                  top: 562,
                  child: SizedBox(
                    width: 339,
                    height: 27,
                    child: Center(
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          height: 1.38,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
