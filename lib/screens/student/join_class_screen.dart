import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/class_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/gradient_container.dart';
import '../../utils/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        AppTheme.darkBackground,
                        AppTheme.darkBackground.withOpacity(0.8),
                      ]
                    : [
                        AppTheme.lightPrimaryStart.withOpacity(0.05),
                        AppTheme.lightPrimaryEnd.withOpacity(0.02),
                      ],
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar with back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark 
                                ? AppTheme.darkSurface
                                : AppTheme.lightSurface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Icon with gradient background
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient(isDark),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isDark
                                        ? AppTheme.darkPrimaryStart
                                        : AppTheme.lightPrimaryStart)
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.school,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Title with gradient
                        ShaderMask(
                          shaderCallback: (bounds) => AppTheme.primaryGradient(isDark).createShader(bounds),
                          child: Text(
                            'Join a Class',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Text(
                          'Enter the class code to join',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark 
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Form in gradient container
                        GradientContainer(
                          padding: const EdgeInsets.all(24),
                          child: Form(
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
                                      hintText: 'Enter the code from your lecturer',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.code),
                                      filled: true,
                                      fillColor: isDark 
                                          ? AppTheme.darkSurface
                                          : AppTheme.lightSurface,
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
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Join button
                                GradientButton(
                                  text: 'Join Class',
                                  onPressed: isLoading ? () {} : _submitForm,
                                  isLoading: isLoading,
                                  width: double.infinity,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Help text
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : AppTheme.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkPrimaryStart.withOpacity(0.2)
                                  : AppTheme.lightPrimaryStart.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkPrimaryStart.withOpacity(0.1)
                                      : AppTheme.lightPrimaryStart.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.help_outline,
                                  size: 20,
                                  color: isDark
                                      ? AppTheme.darkPrimaryStart
                                      : AppTheme.lightPrimaryStart,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ask your lecturer for the class code. The code is unique for each class.',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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