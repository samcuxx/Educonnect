import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/class_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../utils/app_theme.dart';
import '../../models/class_model.dart';

class EditClassScreen extends StatefulWidget {
  final ClassModel classModel;

  const EditClassScreen({Key? key, required this.classModel}) : super(key: key);

  @override
  State<EditClassScreen> createState() => _EditClassScreenState();
}

class _EditClassScreenState extends State<EditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _courseNameController;
  late final TextEditingController _courseCodeController;
  late String _selectedLevel;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _levelOptions = [
    'Level 100',
    'Level 200',
    'Level 300',
    'Level 400',
    'Level 500',
    'Level 600',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing class data
    _courseNameController = TextEditingController(text: widget.classModel.name);
    _courseCodeController = TextEditingController(
      text: widget.classModel.courseCode,
    );
    _selectedLevel = widget.classModel.level;
    _startDate = widget.classModel.startDate;
    _endDate = widget.classModel.endDate;
  }

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
      firstDate:
          isStartDate
              ? DateTime.now().subtract(const Duration(days: 365))
              : _startDate,
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

  void _updateClass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);

      // Call update method in ClassProvider (will need to be implemented)
      await classProvider.updateClass(
        classId: widget.classModel.id,
        name: _courseNameController.text.trim(),
        courseCode: _courseCodeController.text.trim(),
        level: _selectedLevel,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (classProvider.status == ClassProviderStatus.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate update was successful
      } else if (classProvider.status == ClassProviderStatus.error && mounted) {
        setState(() {
          _errorMessage =
              classProvider.errorMessage ?? 'Failed to update class';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Class',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class code display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient(isDark),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.key_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Class Code',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.classModel.code,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Students need this code to join your class',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Class Details',
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

                // Course name field
                TextFormField(
                  controller: _courseNameController,
                  decoration: InputDecoration(
                    labelText: 'Course Name',
                    prefixIcon: const Icon(Icons.class_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
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

                // Course code field
                TextFormField(
                  controller: _courseCodeController,
                  decoration: InputDecoration(
                    labelText: 'Course Code',
                    prefixIcon: const Icon(Icons.code_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
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
                    fillColor: isDark ? Colors.black12 : Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a course code';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Level dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Academic Level',
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
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
                    fillColor: isDark ? Colors.black12 : Colors.white,
                  ),
                  dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                  value: _selectedLevel,
                  items:
                      _levelOptions.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLevel = value;
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

                // Start date field
                GestureDetector(
                  onTap: () => _selectDate(context, true),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
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
                        fillColor: isDark ? Colors.black12 : Colors.white,
                      ),
                      controller: TextEditingController(
                        text: DateFormat('MMMM d, yyyy').format(_startDate),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // End date field
                GestureDetector(
                  onTap: () => _selectDate(context, false),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
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
                        fillColor: isDark ? Colors.black12 : Colors.white,
                      ),
                      controller: TextEditingController(
                        text: DateFormat('MMMM d, yyyy').format(_endDate),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    width: double.infinity,
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Update button
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: 'Update Class',
                    onPressed: _updateClass,
                    isLoading: _isLoading,
                    useSecondaryGradient: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
