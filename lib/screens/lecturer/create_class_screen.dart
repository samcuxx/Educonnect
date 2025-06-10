import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/class_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../utils/app_theme.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({Key? key}) : super(key: key);

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  String _selectedLevel = 'Level 100';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(
    const Duration(days: 90),
  ); // 3 months from now

  final List<String> _levelOptions = [
    'Level 100',
    'Level 200',
    'Level 300',
    'Level 400',
    'Level 500',
    'Level 600',
  ];

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 2),
      ), // 2 years ahead
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 90));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);

      await classProvider.createClass(
        name: _courseNameController.text.trim(),
        courseCode: _courseCodeController.text.trim(),
        level: _selectedLevel,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (classProvider.status == ClassProviderStatus.success && mounted) {
        // Get the newly created class which should be the first one in the list
        final newClass =
            classProvider.classes.isNotEmpty
                ? classProvider.classes.first
                : null;

        if (newClass != null) {
          // Show dialog with class code
          await _showClassCodeDialog(newClass.code);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (classProvider.status == ClassProviderStatus.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              classProvider.errorMessage ?? 'Failed to create class',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClassCodeDialog(String classCode) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            title: Column(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
                const SizedBox(height: 16),
                Text(
                  'Class Created Successfully!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Share this code with your students:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient(isDark),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    classCode,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Students will need this code to join your class.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark
                          ? AppTheme.darkSecondaryStart
                          : AppTheme.lightSecondaryStart,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: () {
                  // Copy to clipboard
                  Clipboard.setData(ClipboardData(text: classCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Class code copied to clipboard'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Copy Code',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    final isLoading = classProvider.status == ClassProviderStatus.loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Class',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with gradient background
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient(isDark),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.class_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'Create a Class',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                  ),
                ),
              ),

              Center(
                child: Text(
                  'Set up your new class',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Form fields
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class Information',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Course Name
                      TextFormField(
                        controller: _courseNameController,
                        decoration: InputDecoration(
                          labelText: 'Course Name',
                          hintText: 'e.g., Linear Algebra II',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart,
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.book_outlined),
                          filled: true,
                          fillColor: isDark ? Colors.black12 : Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a course name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Course Code
                      TextFormField(
                        controller: _courseCodeController,
                        decoration: InputDecoration(
                          labelText: 'Course Code',
                          hintText: 'e.g., MATH241',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart,
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.code_outlined),
                          filled: true,
                          fillColor: isDark ? Colors.black12 : Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a course code';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.characters,
                      ),

                      const SizedBox(height: 16),

                      // Level Selection
                      DropdownButtonFormField<String>(
                        value: _selectedLevel,
                        decoration: InputDecoration(
                          labelText: 'Level',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart,
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.school_outlined),
                          filled: true,
                          fillColor: isDark ? Colors.black12 : Colors.white,
                        ),
                        dropdownColor:
                            isDark ? AppTheme.darkSurface : Colors.white,
                        items:
                            _levelOptions.map((String level) {
                              return DropdownMenuItem<String>(
                                value: level,
                                child: Text(level),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedLevel = newValue;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Class Duration',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Date Selection
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectDate(context, true),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Start Date',
                                    prefixIcon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.arrow_drop_down,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide(
                                        color:
                                            isDark
                                                ? AppTheme.darkBorder
                                                : AppTheme.lightBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide(
                                        color:
                                            isDark
                                                ? AppTheme.darkSecondaryStart
                                                : AppTheme.lightSecondaryStart,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor:
                                        isDark ? Colors.black12 : Colors.white,
                                  ),
                                  controller: TextEditingController(
                                    text: DateFormat(
                                      'MMMM d, yyyy',
                                    ).format(_startDate),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectDate(context, false),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'End Date',
                                    prefixIcon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.arrow_drop_down,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide(
                                        color:
                                            isDark
                                                ? AppTheme.darkBorder
                                                : AppTheme.lightBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide(
                                        color:
                                            isDark
                                                ? AppTheme.darkSecondaryStart
                                                : AppTheme.lightSecondaryStart,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor:
                                        isDark ? Colors.black12 : Colors.white,
                                  ),
                                  controller: TextEditingController(
                                    text: DateFormat(
                                      'MMMM d, yyyy',
                                    ).format(_endDate),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppTheme.darkSecondaryStart.withOpacity(0.1)
                                : AppTheme.lightSecondaryStart.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isDark
                                  ? AppTheme.darkSecondaryStart.withOpacity(0.3)
                                  : AppTheme.lightSecondaryStart.withOpacity(
                                    0.3,
                                  ),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 20,
                        color:
                            isDark
                                ? AppTheme.darkSecondaryStart
                                : AppTheme.lightSecondaryStart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Students will be able to join using the class code that will be generated.',
                        style: GoogleFonts.inter(
                          color:
                              isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Create Class',
                  onPressed: isLoading ? () {} : _submitForm,
                  isLoading: isLoading,
                  useSecondaryGradient: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
