import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          Positioned.fill(
            child: Image.asset(
              'assets/images/startingbackground.png',
              fit: BoxFit.cover, 
            ),
          ),


          Positioned.fill(
            child: Container( 
             
            ),
          ),
          Column(
            children: [
              const Spacer(), 

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFD605B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 5,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          "Get Started",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),


                    Row(
                      children: const [
                        Expanded(
                            child: Divider(
                          color: Colors.orange,
                          thickness: 1,
                          endIndent: 8,
                        )),
                        Text("OR",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            )),
                        Expanded(
                            child: Divider(
                          color: Colors.orange,
                          thickness: 1,
                          indent: 8,
                        )),
                      ],
                    ),
                    const SizedBox(height: 20),


                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        onPressed: () {},
                        child: const Text(
                          "Sign Up with Google",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF31343D),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text.rich(
                        TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: Colors.white70),
                          children: [
                            TextSpan(
                              text: "Sign In",
                              style: TextStyle(
                                color: Color(0xFFFD605B),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}
