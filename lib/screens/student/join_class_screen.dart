import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/class_provider.dart';
import '../../widgets/custom_button.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({Key? key}) : super(key: key);

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _classCodeController = TextEditingController();
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _classCodeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      
      await classProvider.joinClass(
        classCode: _classCodeController.text.trim(),
      );

      if (classProvider.status == ClassProviderStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined the class'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else if (classProvider.status == ClassProviderStatus.error) {
        if (mounted) {
          // Show error message and shake the input field
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(classProvider.errorMessage ?? 'Failed to join class'),
              backgroundColor: Colors.red,
            ),
          );
          _shakeController.forward();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    final isLoading = classProvider.status == ClassProviderStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Class'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school,
                size: 72,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Enter a class code to join',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Ask your lecturer for the code',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Code input field with shake animation
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: TextFormField(
                        controller: _classCodeController,
                        decoration: InputDecoration(
                          labelText: 'Class Code',
                          hintText: 'e.g., MATH241-XR72',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.code),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a class code';
                          }
                          return null;
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          letterSpacing: 2,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Join button
                    CustomButton(
                      text: 'Join Class',
                      onPressed: isLoading ? () {} : _submitForm,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 