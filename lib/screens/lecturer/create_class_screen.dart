import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/class_provider.dart';
import '../../widgets/custom_button.dart';

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
  DateTime _endDate = DateTime.now().add(const Duration(days: 90)); // 3 months from now

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
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // 2 years ahead
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

      if (classProvider.status == ClassProviderStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Class created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else if (classProvider.status == ClassProviderStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(classProvider.errorMessage ?? 'Failed to create class'),
              backgroundColor: Colors.red,
            ),
          );
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
        title: const Text('Create a Class'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Course Name
              TextFormField(
                controller: _courseNameController,
                decoration: InputDecoration(
                  labelText: 'Course Name',
                  hintText: 'e.g., Linear Algebra II',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Course Code
              TextFormField(
                controller: _courseCodeController,
                decoration: InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g., MATH241',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Level/Year
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                decoration: InputDecoration(
                  labelText: 'Level/Year',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _levelOptions.map((String level) {
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
              const SizedBox(height: 20),
              
              // Start Date
              GestureDetector(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Semester Start Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // End Date
              GestureDetector(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Semester End Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Submit Button
              CustomButton(
                text: 'Save Class',
                onPressed: isLoading ? () {} : _submitForm,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 