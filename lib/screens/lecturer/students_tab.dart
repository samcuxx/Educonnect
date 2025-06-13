import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/student_management_provider.dart';
import '../../models/student_management_model.dart';
import '../../models/class_model.dart';
import '../../utils/dialog_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/student_detail_card.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_container.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({Key? key}) : super(key: key);

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedClassId;
  final bool _isSearchFocused = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize with first class if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelectedClass();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeSelectedClass() {
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentManagementProvider>(
      context,
      listen: false,
    );

    if (classProvider.classes.isNotEmpty && _selectedClassId == null) {
      final firstClassId = classProvider.classes.first.id;
      setState(() {
        _selectedClassId = firstClassId;
      });

      // Load students for this class
      studentProvider.setSelectedClass(firstClassId);
    }
  }

  Future<void> _refreshStudents() async {
    if (_selectedClassId != null) {
      final studentProvider = Provider.of<StudentManagementProvider>(
        context,
        listen: false,
      );
      await studentProvider.loadStudentsForClass(_selectedClassId!);
    }
  }

  void _onClassChanged(String? classId) {
    if (classId != null && classId != _selectedClassId) {
      setState(() {
        _selectedClassId = classId;
      });

      // Clear search when changing class
      _searchController.clear();

      // Load students for the selected class
      final studentProvider = Provider.of<StudentManagementProvider>(
        context,
        listen: false,
      );
      studentProvider.clearSearch();
      studentProvider.setSelectedClass(classId);
    }
  }

  void _searchStudents(String query) {
    final studentProvider = Provider.of<StudentManagementProvider>(
      context,
      listen: false,
    );
    studentProvider.searchStudents(query);
  }

  Future<void> _confirmRemoveStudent(
    BuildContext context,
    ManagedStudentModel student,
  ) async {
    // Get references before showing the dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final studentProvider = Provider.of<StudentManagementProvider>(
      context,
      listen: false,
    );
    final studentName = student.fullName;
    final membershipId = student.membershipId;

    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Remove Student',
      message:
          'Are you sure you want to remove $studentName from this class? This action cannot be undone.',
      confirmButtonText: 'Remove',
      isDangerous: true,
    );

    if (confirmed && mounted) {
      try {
        // Show loading indicator
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Text('Removing $studentName...'),
              ],
            ),
            duration: const Duration(seconds: 60),
          ),
        );

        // Remove the student
        await studentProvider.removeStudentFromClass(membershipId);

        if (mounted) {
          // Show success message
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('$studentName has been removed from the class'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Show error message
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to remove student: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showStudentDetails(BuildContext context, ManagedStudentModel student) {
    showDialog(
      context: context,
      builder: (context) => StudentDetailCard(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classProvider = Provider.of<ClassProvider>(context);
    final studentProvider = Provider.of<StudentManagementProvider>(context);
    final classes = classProvider.classes;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and class selector
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with gradient
                  ShaderMask(
                    shaderCallback:
                        (bounds) => AppTheme.secondaryGradient(
                          isDark,
                        ).createShader(bounds),
                    child: Text(
                      'Student Management',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage students enrolled in your classes',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color:
                          isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Class selector dropdown
                  if (classes.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppTheme.darkSurfaceVariant
                                : AppTheme.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Create classes to manage students',
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
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppTheme.darkSurface
                                : AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: ButtonTheme(
                          alignedDropdown: true,
                          child: DropdownButton<String>(
                            value: _selectedClassId,
                            isExpanded: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color:
                                  isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            hint: Text(
                              'Select a class',
                              style: GoogleFonts.inter(
                                color:
                                    isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            items:
                                classes.map((ClassModel classModel) {
                                  return DropdownMenuItem<String>(
                                    value: classModel.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient:
                                                AppTheme.secondaryGradient(
                                                  isDark,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.class_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '${classModel.courseCode} - ${classModel.name}',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? AppTheme.darkTextPrimary
                                                      : AppTheme
                                                          .lightTextPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged: _onClassChanged,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Search and stats area
            if (classes.isNotEmpty && _selectedClassId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Column(
                  children: [
                    // Search field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or ID',
                          hintStyle: GoogleFonts.inter(
                            color:
                                isDark
                                    ? AppTheme.darkTextSecondary.withOpacity(
                                      0.7,
                                    )
                                    : AppTheme.lightTextSecondary.withOpacity(
                                      0.7,
                                    ),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color:
                                isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color:
                                          isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.lightTextSecondary,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      studentProvider.clearSearch();
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor:
                              isDark
                                  ? AppTheme.darkInputFill
                                  : AppTheme.lightInputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                        style: GoogleFonts.inter(
                          color:
                              isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                        ),
                        onChanged: _searchStudents,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Statistics cards
                    Row(
                      children: [
                        Expanded(
                          child: GradientContainer(
                            useSecondaryGradient: true,
                            padding: const EdgeInsets.all(16),
                            borderRadius: 28,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.people_alt_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Students',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      studentProvider.students.length
                                          .toString(),
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (studentProvider.isSearching) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppTheme.darkSurfaceVariant
                                        : AppTheme.lightSurfaceVariant,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
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
                                              ? AppTheme.darkSecondaryStart
                                                  .withOpacity(0.2)
                                              : AppTheme.lightSecondaryStart
                                                  .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.filter_list_rounded,
                                      color:
                                          isDark
                                              ? AppTheme.darkSecondaryStart
                                              : AppTheme.lightSecondaryStart,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Filtered',
                                          style: GoogleFonts.inter(
                                            color:
                                                isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme
                                                        .lightTextSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${studentProvider.students.length} results',
                                          style: GoogleFonts.inter(
                                            color:
                                                isDark
                                                    ? AppTheme.darkTextPrimary
                                                    : AppTheme.lightTextPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

            // Student list
            Expanded(child: _buildStudentsList(context, studentProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList(
    BuildContext context,
    StudentManagementProvider studentProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedClassId == null) {
      return const EmptyState(
        icon: Icons.class_outlined,
        title: 'No Classes Available',
        message: 'Create classes to manage students',
      );
    }

    if (studentProvider.status == StudentManagementStatus.loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark
                    ? AppTheme.darkSecondaryStart
                    : AppTheme.lightSecondaryStart,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading students...',
              style: GoogleFonts.inter(
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (studentProvider.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Error Loading Students',
        message: studentProvider.error ?? 'Unknown error occurred',
      );
    }

    if (studentProvider.students.isEmpty) {
      if (studentProvider.isSearching) {
        return EmptyState(
          icon: Icons.search_off,
          title: 'No Matches',
          message: 'No students match "${studentProvider.searchQuery}"',
        );
      } else {
        return const EmptyState(
          icon: Icons.people_outline,
          title: 'No Students Enrolled',
          message: 'Students who join with the class code will appear here',
        );
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      itemCount: studentProvider.students.length,
      itemBuilder: (context, index) {
        final student = studentProvider.students[index];
        return _buildStudentListItem(context, student);
      },
    );
  }

  Widget _buildStudentListItem(
    BuildContext context,
    ManagedStudentModel student,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Slidable(
        key: ValueKey(student.membershipId),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (context) => _confirmRemoveStudent(context, student),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Remove',
              borderRadius: BorderRadius.circular(28),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              onTap: () => _showStudentDetails(context, student),
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    StudentAvatar(
                      imageUrl: student.profileImageUrl,
                      name: student.fullName,
                      radius: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color:
                                  isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.email,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color:
                                  isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? AppTheme.darkSecondaryStart
                                              .withOpacity(0.2)
                                          : AppTheme.lightSecondaryStart
                                              .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  student.studentNumber,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark
                                            ? AppTheme.darkSecondaryStart
                                            : AppTheme.lightSecondaryStart,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color:
                                    isDark
                                        ? AppTheme.darkTextTertiary
                                        : AppTheme.lightTextTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                student.joinedAtFormatted,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? AppTheme.darkTextTertiary
                                          : AppTheme.lightTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppTheme.darkSurfaceVariant
                                : AppTheme.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onPressed: () => _showStudentDetails(context, student),
                        color:
                            isDark
                                ? AppTheme.darkSecondaryStart
                                : AppTheme.lightSecondaryStart,
                        padding: EdgeInsets.zero,
                      ),
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
}
