import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import '../models/class_model.dart';
import '../models/user_model.dart';
import '../models/announcement_model.dart';
import '../models/resource_model.dart';
import '../models/assignment_model.dart';
import '../models/submission_model.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';
import 'submissions_screen.dart';

class ClassDetailsScreen extends StatefulWidget {
  final ClassModel classModel;
  
  const ClassDetailsScreen({
    Key? key, 
    required this.classModel,
  }) : super(key: key);

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingCount = false;
  bool _isLoadingAnnouncements = false;
  bool _isLoadingResources = false;
  bool _isLoadingAssignments = false;
  int _studentsCount = 0;
  List<AnnouncementModel> _announcements = [];
  List<ResourceModel> _resources = [];
  List<AssignmentModel> _assignments = [];
  Map<String, bool> _assignmentSubmissions = {}; // Track if student has submitted
  DateTime? _lastAnnouncementCheck;
  bool _initialLoadDone = false;
  
  // Add new properties for resource downloads
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadedFiles = {};
  
  // Add new properties for assignment downloads
  Map<String, double> _assignmentDownloadProgress = {};
  Map<String, String> _downloadedAssignments = {};
  
  // Add submission download tracking
  Map<String, double> _submissionDownloadProgress = {};
  Map<String, String> _downloadedSubmissions = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Only fetch student count if the user is a lecturer
    if (authProvider.isLecturer) {
      _loadStudentsCount();
    }
    
    // Set up tab controller listener
    _tabController.addListener(_handleTabChange);
    
    // Initial load of resources and check for announcements
    _checkAnnouncementUpdates();
    _loadCachedAnnouncements();
    _loadResources();
    _loadAssignments();
    
    // Load downloaded files info
    _loadDownloadedFiles();
    _loadDownloadedAssignments();
    _loadDownloadedSubmissions();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Handle tab changes
  void _handleTabChange() {
    if (_tabController.index == 0 && !_isLoadingAnnouncements) {
      // If switching to announcements tab, check for updates
      _checkAnnouncementUpdates();
    } else if (_tabController.index == 1) {
      // If switching to resources tab
      _loadResources();
    } else if (_tabController.index == 2) {
      // If switching to assignments tab
      _loadAssignments();
    }
  }
  
  // Load assignments for the class
  Future<void> _loadAssignments() async {
    if (_isLoadingAssignments) return;
    
    setState(() {
      _isLoadingAssignments = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      
      final assignments = await supabaseService.getClassAssignments(widget.classModel.id);
      
      // If user is a student, check submission status
      if (!authProvider.isLecturer) {
        for (var assignment in assignments) {
          final hasSubmitted = await supabaseService.hasSubmittedAssignment(assignment.id);
          setState(() {
            _assignmentSubmissions[assignment.id] = hasSubmitted;
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _assignments = assignments;
          _isLoadingAssignments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAssignments = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load assignments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if we need to update announcements (based on time since last check)
  Future<void> _checkAnnouncementUpdates() async {
    // Only check for updates if we haven't checked recently (last 5 minutes)
    final now = DateTime.now();
    if (_lastAnnouncementCheck != null && 
        now.difference(_lastAnnouncementCheck!).inMinutes < 5 &&
        _initialLoadDone) {
      return; // Skip if we checked less than 5 minutes ago
    }
    
    await _loadAnnouncements();
    _lastAnnouncementCheck = now;
    _initialLoadDone = true;
  }
  
  // Load cached announcements from SharedPreferences while we check for updates
  Future<void> _loadCachedAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('announcements_${widget.classModel.id}');
      
      if (cachedData != null) {
        final cachedList = (json.decode(cachedData) as List).map((item) {
          return AnnouncementModel.fromJson(item);
        }).toList();
        
        setState(() {
          _announcements = cachedList;
        });
        print('Loaded ${cachedList.length} announcements from cache');
      }
    } catch (e) {
      print('Error loading cached announcements: $e');
    }
  }

  // Save announcements to SharedPreferences
  Future<void> _cacheAnnouncements(List<AnnouncementModel> announcements) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = announcements.map((a) => a.toJson()).toList();
      await prefs.setString('announcements_${widget.classModel.id}', json.encode(data));
    } catch (e) {
      print('Error caching announcements: $e');
    }
  }
  
  Future<void> _loadStudentsCount() async {
    setState(() {
      _isLoadingCount = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      
      final count = await supabaseService.getClassStudentsCount(widget.classModel.id);
      
      setState(() {
        _studentsCount = count;
        _isLoadingCount = false;
      });
    } catch (e) {
      // Handle error
      setState(() {
        _isLoadingCount = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load students count: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadAnnouncements() async {
    if (_isLoadingAnnouncements) return;
    
    setState(() {
      _isLoadingAnnouncements = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      
      final announcements = await supabaseService.getClassAnnouncements(widget.classModel.id);
      
      // Cache the fetched announcements
      _cacheAnnouncements(announcements);
      
      if (mounted) {
        setState(() {
          _announcements = announcements;
          _isLoadingAnnouncements = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAnnouncements = false;
        });
        
        // Only show error if we don't have cached data
        if (_announcements.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load announcements: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _loadResources() async {
    setState(() {
      _isLoadingResources = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      
      final resources = await supabaseService.getClassResources(widget.classModel.id);
      
      setState(() {
        _resources = resources;
        _isLoadingResources = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingResources = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load resources: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Show confirmation dialog before leaving or deleting a class
  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  // Handle leaving a class (for students)
  Future<void> _leaveClass() async {
    final confirmed = await _showConfirmationDialog(
      'Leave Class',
      'Are you sure you want to leave this class? You will need the class code to rejoin.',
    );
    
    if (!confirmed) return;
    
    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      await classProvider.leaveClass(widget.classModel.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the class'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave class: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Handle deleting a class (for lecturers)
  Future<void> _deleteClass() async {
    final confirmed = await _showConfirmationDialog(
      'Delete Class',
      'Are you sure you want to delete this class? This action cannot be undone and will remove all students from the class.',
    );
    
    if (!confirmed) return;
    
    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      await classProvider.deleteClass(widget.classModel.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete class: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Create a new announcement
  Future<void> _createAnnouncement() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Announcement',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      'title': titleController.text.trim(),
                      'message': messageController.text.trim(),
                    });
                  }
                },
                child: const Text('Post Announcement'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ).then((data) async {
      if (data != null && data is Map<String, String>) {
        try {
          setState(() {
            _isLoadingAnnouncements = true;
          });
          
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final supabaseService = authProvider.supabaseService;
          
          final announcement = await supabaseService.createAnnouncement(
            classId: widget.classModel.id,
            title: data['title']!,
            message: data['message']!,
          );
          
          setState(() {
            _announcements.insert(0, announcement);
            _isLoadingAnnouncements = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Announcement posted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoadingAnnouncements = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to post announcement: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }
  
  // Upload a new resource file
  Future<void> _uploadResource() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    File? selectedFile;
    String? fileName;
    bool isUploading = false;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Upload Resource',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // File picker
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Select File'),
                          onPressed: () async {
                            try {
                              // Use file_selector to pick files
                              final XTypeGroup allFiles = XTypeGroup(
                                label: 'All Files',
                                extensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png'],
                              );
                              
                              final XFile? pickedFile = await openFile(
                                acceptedTypeGroups: [allFiles],
                              );
                              
                              if (pickedFile != null) {
                                final path = pickedFile.path;
                                print("Selected file path: $path");
                                
                                // Create the file object
                                final file = File(path);
                                
                                // Check if file exists and is readable
                                if (await file.exists()) {
                                  setModalState(() {
                                    selectedFile = file;
                                    fileName = pickedFile.name;
                                  });
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('File not found or cannot be accessed'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              print("Error picking file: $e");
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error selecting file: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (fileName != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName!,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (selectedFile != null) FutureBuilder<int>(
                                        future: selectedFile!.length(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            final kb = snapshot.data! / 1024;
                                            return Text(
                                              '${kb.toStringAsFixed(1)} KB',
                                              style: const TextStyle(fontSize: 12),
                                            );
                                          }
                                          return const SizedBox();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedFile = null;
                                      fileName = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isUploading ? null : () async {
                      if (formKey.currentState!.validate() && selectedFile != null) {
                        try {
                          // Check if file still exists before proceeding
                          if (!await selectedFile!.exists()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('File no longer exists or cannot be accessed'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          setModalState(() {
                            isUploading = true;
                          });
                          
                          Navigator.pop(context, {
                            'title': titleController.text.trim(),
                            'file': selectedFile,
                          });
                        } catch (e) {
                          print("Error checking file before upload: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error preparing file: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setModalState(() {
                            isUploading = false;
                          });
                        }
                      } else if (selectedFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a file'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: isUploading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Preparing...'),
                            ],
                          )
                        : const Text('Upload Resource'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        try {
          setState(() {
            _isLoadingResources = true;
          });
          
          // Show uploading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Uploading resource...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
          
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final supabaseService = authProvider.supabaseService;
          
          final resource = await supabaseService.uploadResource(
            classId: widget.classModel.id,
            title: data['title'],
            file: data['file'],
          );
          
          setState(() {
            _resources.insert(0, resource);
            _isLoadingResources = false;
          });
          
          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Resource uploaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          print("Error during upload process: $e");
          setState(() {
            _isLoadingResources = false;
          });
          
          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload resource: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  // Add method to load downloaded files info
  Future<void> _loadDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_resources_${widget.classModel.id}');
      
      if (fileMap != null) {
        setState(() {
          _downloadedFiles = Map<String, String>.from(json.decode(fileMap));
        });
        
        // Verify files still exist
        for (final resourceId in _downloadedFiles.keys.toList()) {
          final filePath = _downloadedFiles[resourceId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              setState(() {
                _downloadedFiles.remove(resourceId);
              });
            }
          }
        }
        
        // Save changes if any files were removed
        await _saveDownloadedFiles();
      }
    } catch (e) {
      print('Error loading downloaded files: $e');
    }
  }
  
  // Add method to save downloaded files info
  Future<void> _saveDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_resources_${widget.classModel.id}',
        json.encode(_downloadedFiles)
      );
    } catch (e) {
      print('Error saving downloaded files: $e');
    }
  }
  
  // Add method to download a file
  Future<void> _downloadFile(ResourceModel resource) async {
    if (_downloadProgress.containsKey(resource.id)) {
      return; // Already downloading
    }
    
    try {
      // Initialize progress
      setState(() {
        _downloadProgress[resource.id] = 0.0;
      });
      
      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/EduConnect/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Extract the original filename from the URL
      final uri = Uri.parse(resource.fileUrl);
      String fileName = path.basename(uri.path);
      
      // If the filename doesn't have an extension from the URL, try to add one based on resource.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(resource.fileType);
        fileName = '${resource.id}$extension';
      }
      
      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      
      // Delete the file if it already exists
      if (await file.exists()) {
        await file.delete();
      }
      
      // Download the file with progress reporting
      final response = await http.Client().send(http.Request('GET', uri));
      final contentLength = response.contentLength ?? 0;
      
      final sink = file.openWrite();
      int bytesReceived = 0;
      
      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        
        if (contentLength > 0) {
          setState(() {
            _downloadProgress[resource.id] = bytesReceived / contentLength;
          });
        }
      }).asFuture();
      
      await sink.flush();
      await sink.close();
      
      // Save the file path
      setState(() {
        _downloadedFiles[resource.id] = filePath;
        _downloadProgress.remove(resource.id);
      });
      
      // Update the stored list of downloaded files
      await _saveDownloadedFiles();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${resource.title} downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading file: $e');
      
      // Remove progress indicator
      setState(() {
        _downloadProgress.remove(resource.id);
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download ${resource.title}: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Add method to open a downloaded file
  Future<void> _openFile(ResourceModel resource) async {
    try {
      final filePath = _downloadedFiles[resource.id];
      if (filePath == null) {
        throw Exception('File not found');
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }
      
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening file: $e');
      
      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') || e.toString().contains('not found')) {
        setState(() {
          _downloadedFiles.remove(resource.id);
        });
        await _saveDownloadedFiles();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Helper method to get file extension from file type
  String _getExtensionFromFileType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return '.pdf';
      case 'word': return '.docx';
      case 'excel': return '.xlsx';
      case 'powerpoint': return '.pptx';
      case 'image': return '.jpg';
      case 'text': return '.txt';
      default: return '';
    }
  }

  // Add method to load downloaded assignments info
  Future<void> _loadDownloadedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_assignments_${widget.classModel.id}');
      
      if (fileMap != null) {
        setState(() {
          _downloadedAssignments = Map<String, String>.from(json.decode(fileMap));
        });
        
        // Verify files still exist
        for (final assignmentId in _downloadedAssignments.keys.toList()) {
          final filePath = _downloadedAssignments[assignmentId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              setState(() {
                _downloadedAssignments.remove(assignmentId);
              });
            }
          }
        }
        
        // Save changes if any files were removed
        await _saveDownloadedAssignments();
      }
    } catch (e) {
      print('Error loading downloaded assignments: $e');
    }
  }

  // Add method to save downloaded assignments info
  Future<void> _saveDownloadedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_assignments_${widget.classModel.id}',
        json.encode(_downloadedAssignments)
      );
    } catch (e) {
      print('Error saving downloaded assignments: $e');
    }
  }

  // Add method to download an assignment file
  Future<void> _downloadAssignmentFile(AssignmentModel assignment) async {
    if (_assignmentDownloadProgress.containsKey(assignment.id)) {
      return; // Already downloading
    }
    
    try {
      // Initialize progress
      setState(() {
        _assignmentDownloadProgress[assignment.id] = 0.0;
      });
      
      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/EduConnect/Downloads/Assignments');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Extract the original filename from the URL
      final uri = Uri.parse(assignment.fileUrl!);
      String fileName = path.basename(uri.path);
      
      // If the filename doesn't have an extension from the URL, try to add one based on resource.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(assignment.fileType);
        fileName = '${assignment.id}$extension';
      }
      
      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      
      // Delete the file if it already exists
      if (await file.exists()) {
        await file.delete();
      }
      
      // Download the file with progress reporting
      final response = await http.Client().send(http.Request('GET', uri));
      final contentLength = response.contentLength ?? 0;
      
      final sink = file.openWrite();
      int bytesReceived = 0;
      
      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        
        if (contentLength > 0) {
          setState(() {
            _assignmentDownloadProgress[assignment.id] = bytesReceived / contentLength;
          });
        }
      }).asFuture();
      
      await sink.flush();
      await sink.close();
      
      // Save the file path
      setState(() {
        _downloadedAssignments[assignment.id] = filePath;
        _assignmentDownloadProgress.remove(assignment.id);
      });
      
      // Update the stored list of downloaded files
      await _saveDownloadedAssignments();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${assignment.title} downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading assignment file: $e');
      
      // Remove progress indicator
      setState(() {
        _assignmentDownloadProgress.remove(assignment.id);
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download ${assignment.title}: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Add method to open a downloaded assignment file
  Future<void> _openAssignmentFile(AssignmentModel assignment) async {
    try {
      final filePath = _downloadedAssignments[assignment.id];
      if (filePath == null) {
        throw Exception('File not found');
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }
      
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening assignment file: $e');
      
      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') || e.toString().contains('not found')) {
        setState(() {
          _downloadedAssignments.remove(assignment.id);
        });
        await _saveDownloadedAssignments();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Add method to load downloaded submissions info
  Future<void> _loadDownloadedSubmissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_submissions_${widget.classModel.id}');
      
      if (fileMap != null) {
        setState(() {
          _downloadedSubmissions = Map<String, String>.from(json.decode(fileMap));
        });
        
        // Verify files still exist
        for (final submissionId in _downloadedSubmissions.keys.toList()) {
          final filePath = _downloadedSubmissions[submissionId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              setState(() {
                _downloadedSubmissions.remove(submissionId);
              });
            }
          }
        }
        
        // Save changes if any files were removed
        await _saveDownloadedSubmissions();
      }
    } catch (e) {
      print('Error loading downloaded submissions: $e');
    }
  }

  // Add method to save downloaded submissions info
  Future<void> _saveDownloadedSubmissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_submissions_${widget.classModel.id}',
        json.encode(_downloadedSubmissions)
      );
    } catch (e) {
      print('Error saving downloaded submissions: $e');
    }
  }

  // Add method to download a submission file
  Future<void> _downloadSubmissionFile(SubmissionModel submission) async {
    if (_submissionDownloadProgress.containsKey(submission.id) || submission.fileUrl == null) {
      return; // Already downloading or no file URL
    }
    
    try {
      // Initialize progress
      setState(() {
        _submissionDownloadProgress[submission.id] = 0.0;
      });
      
      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/EduConnect/Downloads/Submissions');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Extract the original filename from the URL
      final uri = Uri.parse(submission.fileUrl!);
      String fileName = path.basename(uri.path);
      
      // If the filename doesn't have an extension from the URL, try to add one based on submission.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(submission.fileType);
        fileName = '${submission.id}$extension';
      }
      
      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      
      // Delete the file if it already exists
      if (await file.exists()) {
        await file.delete();
      }
      
      // Download the file with progress reporting
      final response = await http.Client().send(http.Request('GET', uri));
      final contentLength = response.contentLength ?? 0;
      
      final sink = file.openWrite();
      int bytesReceived = 0;
      
      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        
        if (contentLength > 0) {
          setState(() {
            _submissionDownloadProgress[submission.id] = bytesReceived / contentLength;
          });
        }
      }).asFuture();
      
      await sink.flush();
      await sink.close();
      
      // Save the file path
      setState(() {
        _downloadedSubmissions[submission.id] = filePath;
        _submissionDownloadProgress.remove(submission.id);
      });
      
      // Update the stored list of downloaded files
      await _saveDownloadedSubmissions();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${submission.studentName}\'s submission downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading submission file: $e');
      
      // Remove progress indicator
      setState(() {
        _submissionDownloadProgress.remove(submission.id);
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download submission: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Add method to open a downloaded submission file
  Future<void> _openSubmissionFile(SubmissionModel submission) async {
    try {
      final filePath = _downloadedSubmissions[submission.id];
      if (filePath == null) {
        throw Exception('File not found');
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }
      
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening submission file: $e');
      
      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') || e.toString().contains('not found')) {
        setState(() {
          _downloadedSubmissions.remove(submission.id);
        });
        await _saveDownloadedSubmissions();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isDark ? [
              AppTheme.darkSecondaryStart,
              AppTheme.darkSecondaryEnd,
            ] : [
              AppTheme.lightSecondaryStart,
              AppTheme.lightSecondaryEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            widget.classModel.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
        ),
        actions: [
          // Add action button based on user role
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
              ),
              onSelected: (value) {
                if (value == 'leave') {
                  _leaveClass();
                } else if (value == 'delete') {
                  _deleteClass();
                } else if (value == 'details') {
                  _showClassDetails();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text('Class Details'),
                    ],
                  ),
                ),
                if (isLecturer)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Delete Class'),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Leave Class'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                    ? AppTheme.darkTextSecondary.withOpacity(0.1)
                    : AppTheme.lightTextSecondary.withOpacity(0.1),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
              ),
              labelColor: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
              unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              indicatorColor: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
                              tabs: [
                Tab(
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabController.index == 0 
                          ? Icons.announcement 
                          : Icons.announcement_outlined,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      const Text('Updates'),
                    ],
                  ),
                ),
                Tab(
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabController.index == 1 
                          ? Icons.folder 
                          : Icons.folder_outlined,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      const Text('Resources'),
                    ],
                  ),
                ),
                Tab(
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabController.index == 2 
                          ? Icons.assignment 
                          : Icons.assignment_outlined,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      const Text('Tasks'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Add floating action button for lecturers to create announcements, upload resources, or create assignments
      floatingActionButton: isLecturer ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? [
              AppTheme.darkSecondaryStart,
              AppTheme.darkSecondaryEnd,
            ] : [
              AppTheme.lightSecondaryStart,
              AppTheme.lightSecondaryEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            if (_tabController.index == 0) {
              _createAnnouncement();
            } else if (_tabController.index == 1) {
              _uploadResource();
            } else {
              _createAssignment();
            }
          },
          tooltip: _tabController.index == 0 
            ? 'Add Announcement' 
            : _tabController.index == 1 
              ? 'Upload Resource' 
              : 'Create Assignment',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(
            _tabController.index == 0 
              ? Icons.post_add
              : _tabController.index == 1 
                ? Icons.upload_rounded
                : Icons.add_task_rounded,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ) : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Announcements Tab
          _buildAnnouncementsTab(context, isLecturer),
          
          // Resources Tab
          _buildResourcesTab(context, isLecturer),
          
          // Assignments Tab
          _buildAssignmentsTab(context, isLecturer),
        ],
      ),
    );
  }
  
  Widget _buildAnnouncementsTab(BuildContext context, bool isLecturer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      displacement: 40.0,
      color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child: _isLoadingAnnouncements && _announcements.isEmpty
        ? Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart
            ),
          ))
        : _announcements.isEmpty
          ? _buildEmptyState(
              context,
              icon: Icons.announcement,
              title: 'No announcements yet',
              message: isLecturer
                ? 'Tap + to post an announcement for your class'
                : 'Stay tuned for updates from your lecturer',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _announcements.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final announcement = _announcements[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showAnnouncementDetails(announcement),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark ? [
                              AppTheme.darkSecondaryStart.withOpacity(0.1),
                              AppTheme.darkSecondaryEnd.withOpacity(0.05),
                            ] : [
                              AppTheme.lightSecondaryStart.withOpacity(0.1),
                              AppTheme.lightSecondaryEnd.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark 
                              ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                              : AppTheme.lightSecondaryStart.withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  DateFormat('MMM d').format(announcement.createdAt),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark 
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('h:mm a').format(announcement.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark 
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              announcement.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              announcement.message,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAnnouncementDetails(AnnouncementModel announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.announcement_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFormattedDate(announcement.createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark
                            ? AppTheme.darkPrimaryStart
                            : AppTheme.lightPrimaryStart).withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        announcement.message,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: (isDark
                            ? AppTheme.darkPrimaryStart
                            : AppTheme.lightPrimaryStart).withOpacity(0.2),
                          child: Text(
                            announcement.postedByName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: isDark
                                ? AppTheme.darkPrimaryStart
                                : AppTheme.lightPrimaryStart,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Posted by',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                            ),
                            Text(
                              announcement.postedByName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResourcesTab(BuildContext context, bool isLecturer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: _loadResources,
      displacement: 40.0,
      color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child: _isLoadingResources && _resources.isEmpty
        ? Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart
            ),
          ))
        : _resources.isEmpty
          ? _buildEmptyState(
              context,
              icon: Icons.folder_open,
              title: 'No resources shared yet',
              message: isLecturer
                ? 'Tap + to upload files for your students'
                : 'Resources will be shared by your lecturer soon',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _resources.length,
              itemBuilder: (context, index) {
                final resource = _resources[index];
                final bool isDownloading = _downloadProgress.containsKey(resource.id);
                final bool isDownloaded = _downloadedFiles.containsKey(resource.id);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isDownloaded ? () => _openFile(resource) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark ? [
                              AppTheme.darkSecondaryStart.withOpacity(0.1),
                              AppTheme.darkSecondaryEnd.withOpacity(0.05),
                            ] : [
                              AppTheme.lightSecondaryStart.withOpacity(0.1),
                              AppTheme.lightSecondaryEnd.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark 
                              ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                              : AppTheme.lightSecondaryStart.withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getFileColor(resource.fileType).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getFileIconData(resource.fileType),
                                    color: _getFileColor(resource.fileType),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        resource.title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(resource.createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDownloaded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Downloaded',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isDownloading)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart
                                            ),
                                            value: _downloadProgress[resource.id],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${(_downloadProgress[resource.id]! * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (resource.fileUrl != null) ...[
                                  Icon(
                                    _getFileIconData(resource.fileType),
                                    size: 16,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Has attachment',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded( // Added Expanded to make the middle section flexible
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart).withOpacity(0.1),
                                        child: Text(
                                          resource.uploadedByName[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible( // Added Flexible to allow text to wrap if needed
                                        child: Text(
                                          'Uploaded by ${resource.uploadedByName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isDownloaded && !isDownloading)
                                  TextButton.icon(
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text('Download'),
                                    onPressed: () => _downloadFile(resource),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced horizontal padding
                                    ),
                                  )
                                else if (isDownloaded)
                                  TextButton.icon(
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('Open'),
                                    onPressed: () => _openFile(resource),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced horizontal padding
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
  
  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Icon _getFileIcon(String fileType) {
    switch (fileType) {
      case 'PDF':
        return Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'Word':
        return Icon(Icons.description, color: Colors.blue);
      case 'Excel':
        return Icon(Icons.table_chart, color: Colors.green);
      case 'PowerPoint':
        return Icon(Icons.slideshow, color: Colors.orange);
      case 'Image':
        return Icon(Icons.image, color: Colors.purple);
      case 'Text':
        return Icon(Icons.article, color: Colors.grey);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }
  
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  // Helper method for formatting date based on how long ago it was posted
  String _getFormattedDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Method to show resource details
  void _showResourceInfoDialog(BuildContext context, ResourceModel resource) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(resource.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('File Type'),
              subtitle: Text(resource.fileType),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Uploaded By'),
              subtitle: Text(resource.uploadedByName),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date Uploaded'),
              subtitle: Text(DateFormat('MMMM d, yyyy').format(resource.createdAt)),
              contentPadding: EdgeInsets.zero,
            ),
            if (_downloadedFiles.containsKey(resource.id))
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Status'),
                subtitle: const Text('Downloaded'),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  // Add helper method for file color based on type
  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'PDF': return Colors.red;
      case 'Word': return Colors.blue;
      case 'Excel': return Colors.green;
      case 'PowerPoint': return Colors.orange;
      case 'Image': return Colors.purple;
      case 'Text': return Colors.grey;
      default: return Colors.grey;
    }
  }

  // Create a new assignment (for lecturers)
  Future<void> _createAssignment() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final deadlineDate = ValueNotifier<DateTime>(
      DateTime.now().add(const Duration(days: 7)),
    );
    File? selectedFile;
    String? fileName;
    bool isUploading = false;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Assignment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  // Deadline picker
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Submission Deadline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: deadlineDate,
                          builder: (context, date, _) {
                            return Row(
                              children: [
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a').format(date),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.calendar_month),
                                  label: const Text('Change'),
                                  onPressed: () async {
                                    final newDate = await showDatePicker(
                                      context: context,
                                      initialDate: date,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    
                                    if (newDate != null) {
                                      final newTime = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(date),
                                      );
                                      
                                      if (newTime != null) {
                                        setModalState(() {
                                          deadlineDate.value = DateTime(
                                            newDate.year,
                                            newDate.month,
                                            newDate.day,
                                            newTime.hour,
                                            newTime.minute,
                                          );
                                        });
                                      }
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // File picker (optional)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Attachment (Optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Select File'),
                          onPressed: () async {
                            try {
                              // Use file_selector to pick files
                              final XTypeGroup allFiles = XTypeGroup(
                                label: 'All Files',
                                extensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png'],
                              );
                              
                              final XFile? pickedFile = await openFile(
                                acceptedTypeGroups: [allFiles],
                              );
                              
                              if (pickedFile != null) {
                                final path = pickedFile.path;
                                
                                // Create the file object
                                final file = File(path);
                                
                                // Check if file exists and is readable
                                if (await file.exists()) {
                                  setModalState(() {
                                    selectedFile = file;
                                    fileName = pickedFile.name;
                                  });
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('File not found or cannot be accessed'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              print("Error picking file: $e");
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error selecting file: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (fileName != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName!,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (selectedFile != null) FutureBuilder<int>(
                                        future: selectedFile!.length(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            final kb = snapshot.data! / 1024;
                                            return Text(
                                              '${kb.toStringAsFixed(1)} KB',
                                              style: const TextStyle(fontSize: 12),
                                            );
                                          }
                                          return const SizedBox();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedFile = null;
                                      fileName = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isUploading ? null : () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          // Check if file still exists before proceeding
                          if (selectedFile != null && !await selectedFile!.exists()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('File no longer exists or cannot be accessed'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          setModalState(() {
                            isUploading = true;
                          });
                          
                          Navigator.pop(context, {
                            'title': titleController.text.trim(),
                            'description': descriptionController.text.trim(),
                            'deadline': deadlineDate.value,
                            'file': selectedFile,
                          });
                        } catch (e) {
                          print("Error preparing assignment: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error preparing assignment: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setModalState(() {
                            isUploading = false;
                          });
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: isUploading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Preparing...'),
                            ],
                          )
                        : const Text('Create Assignment'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        try {
          setState(() {
            _isLoadingAssignments = true;
          });
          
          // Show creating indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Creating assignment...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
          
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final supabaseService = authProvider.supabaseService;
          
          final assignment = await supabaseService.createAssignment(
            classId: widget.classModel.id,
            title: data['title'],
            description: data['description']?.isEmpty ?? true ? null : data['description'],
            deadline: data['deadline'],
            file: data['file'],
          );
          
          setState(() {
            _assignments.insert(0, assignment);
            _isLoadingAssignments = false;
          });
          
          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Assignment created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoadingAssignments = false;
          });
          
          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create assignment: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }
  
  // Submit an assignment (for students)
  Future<void> _submitAssignment(AssignmentModel assignment) async {
    final formKey = GlobalKey<FormState>();
    File? selectedFile;
    String? fileName;
    bool isUploading = false;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Submit: ${assignment.title}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // File picker
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Submission File',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Select File'),
                          onPressed: () async {
                            try {
                              // Use file_selector to pick files
                              final XTypeGroup allFiles = XTypeGroup(
                                label: 'All Files',
                                extensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png'],
                              );
                              
                              final XFile? pickedFile = await openFile(
                                acceptedTypeGroups: [allFiles],
                              );
                              
                              if (pickedFile != null) {
                                final path = pickedFile.path;
                                
                                // Create the file object
                                final file = File(path);
                                
                                // Check if file exists and is readable
                                if (await file.exists()) {
                                  setModalState(() {
                                    selectedFile = file;
                                    fileName = pickedFile.name;
                                  });
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('File not found or cannot be accessed'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              print("Error picking file: $e");
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error selecting file: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (fileName != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName!,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (selectedFile != null) FutureBuilder<int>(
                                        future: selectedFile!.length(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            final kb = snapshot.data! / 1024;
                                            return Text(
                                              '${kb.toStringAsFixed(1)} KB',
                                              style: const TextStyle(fontSize: 12),
                                            );
                                          }
                                          return const SizedBox();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedFile = null;
                                      fileName = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isUploading ? null : () async {
                      if (selectedFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a file to submit'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      try {
                        // Check if file still exists before proceeding
                        if (!await selectedFile!.exists()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('File no longer exists or cannot be accessed'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        setModalState(() {
                          isUploading = true;
                        });
                        
                        Navigator.pop(context, {
                          'file': selectedFile,
                        });
                      } catch (e) {
                        print("Error checking file: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error preparing file: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setModalState(() {
                          isUploading = false;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: isUploading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Submitting...'),
                            ],
                          )
                        : const Text('Submit Assignment'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        try {
          // Show uploading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Submitting assignment...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
          
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final supabaseService = authProvider.supabaseService;
          
          await supabaseService.submitAssignment(
            assignmentId: assignment.id,
            file: data['file'],
          );
          
          // Update submission status
          setState(() {
            _assignmentSubmissions[assignment.id] = true;
          });
          
          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Assignment submitted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to submit assignment: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }
  
  // View assignment submissions (for lecturers)
  void _viewSubmissions(AssignmentModel assignment) {
    // Navigate to the submissions screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmissionsScreen(assignment: assignment),
      ),
    );
  }
  
  IconData _getFileIconData(String fileType) {
    switch (fileType) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'Word':
        return Icons.description;
      case 'Excel':
        return Icons.table_chart;
      case 'PowerPoint':
        return Icons.slideshow;
      case 'Image':
        return Icons.image;
      case 'Text':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  // Build the assignments tab view
  Widget _buildAssignmentsTab(BuildContext context, bool isLecturer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: _loadAssignments,
      displacement: 40.0,
      color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child: _isLoadingAssignments && _assignments.isEmpty
        ? Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart
            ),
          ))
        : _assignments.isEmpty
          ? _buildEmptyState(
              context,
              icon: Icons.assignment_outlined,
              title: 'No assignments yet',
              message: isLecturer
                ? 'Tap + to create an assignment for your students'
                : 'Your lecturer has not posted any assignments yet',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _assignments.length,
              itemBuilder: (context, index) {
                final assignment = _assignments[index];
                final bool hasSubmitted = _assignmentSubmissions[assignment.id] ?? false;
                final bool isOverdue = DateTime.now().isAfter(assignment.deadline);
                final bool isUpcoming = !isOverdue && DateTime.now().difference(assignment.deadline).inDays > -3;
                
                return                 Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => isLecturer ? _viewSubmissions(assignment) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark ? [
                              AppTheme.darkSecondaryStart.withOpacity(0.1),
                              AppTheme.darkSecondaryEnd.withOpacity(0.05),
                            ] : [
                              AppTheme.lightSecondaryStart.withOpacity(0.1),
                              AppTheme.lightSecondaryEnd.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isOverdue && !isLecturer && !hasSubmitted
                              ? Colors.red.withOpacity(0.3)
                              : isDark 
                                ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                                : AppTheme.lightSecondaryStart.withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isOverdue && !hasSubmitted
                                      ? Colors.red
                                      : isUpcoming
                                        ? Colors.orange
                                        : isDark 
                                          ? AppTheme.darkPrimaryStart 
                                          : AppTheme.lightPrimaryStart
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isOverdue && !hasSubmitted
                                      ? Icons.warning_rounded
                                      : isUpcoming
                                        ? Icons.timer
                                        : Icons.assignment_outlined,
                                    color: isOverdue && !hasSubmitted
                                      ? Colors.red
                                      : isUpcoming
                                        ? Colors.orange
                                        : isDark 
                                          ? AppTheme.darkPrimaryStart 
                                          : AppTheme.lightPrimaryStart,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        assignment.title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Due ${DateFormat('MMM d, yyyy • h:mm a').format(assignment.deadline)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isOverdue && !hasSubmitted && !isLecturer
                                            ? Colors.red
                                            : isDark ? Colors.white60 : Colors.black45,
                                          fontWeight: isOverdue && !hasSubmitted && !isLecturer
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLecturer && hasSubmitted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Submitted',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (assignment.description != null && assignment.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                assignment.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  height: 1.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (assignment.fileUrl != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white24 : Colors.black12,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getFileColor(assignment.fileType).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getFileIconData(assignment.fileType),
                                        color: _getFileColor(assignment.fileType),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Assignment Document',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            assignment.fileType,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_downloadedAssignments.containsKey(assignment.id))
                                      TextButton.icon(
                                        icon: const Icon(Icons.open_in_new, size: 16),
                                        label: const Text('Open'),
                                        onPressed: () => _openAssignmentFile(assignment),
                                        style: TextButton.styleFrom(
                                          foregroundColor: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        ),
                                      )
                                    else if (_assignmentDownloadProgress.containsKey(assignment.id))
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart
                                              ),
                                              value: _assignmentDownloadProgress[assignment.id],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(_assignmentDownloadProgress[assignment.id]! * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      TextButton.icon(
                                        icon: const Icon(Icons.download, size: 16),
                                        label: const Text('Download'),
                                        onPressed: () => _downloadAssignmentFile(assignment),
                                        style: TextButton.styleFrom(
                                          foregroundColor: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (assignment.fileUrl != null) ...[
                                  Icon(
                                    _getFileIconData(assignment.fileType),
                                    size: 16,
                                    color: isDark ? Colors.white60 : Colors.black45,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Has attachment',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded( // Added Expanded to make the middle section flexible
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart).withOpacity(0.1),
                                        child: Text(
                                          assignment.assignedByName[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible( // Added Flexible to allow text to wrap if needed
                                        child: Text(
                                          'Posted by ${assignment.assignedByName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.black45,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLecturer && !hasSubmitted)
                                  TextButton.icon(
                                    icon: const Icon(Icons.upload_file, size: 16),
                                    label: Text(isOverdue ? 'Submit Late' : 'Submit'),
                                    onPressed: () => _submitAssignment(assignment),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isOverdue ? Colors.red : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced horizontal padding
                                    ),
                                  )
                                else if (isLecturer)
                                  TextButton.icon(
                                    icon: const Icon(Icons.people, size: 16),
                                    label: const Text('View'),
                                    onPressed: () => _viewSubmissions(assignment),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced horizontal padding
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Add new method to show class details
  void _showClassDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark 
                ? AppTheme.darkTextSecondary.withOpacity(0.1)
                : AppTheme.lightTextSecondary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? [
                    AppTheme.darkSecondaryStart,
                    AppTheme.darkSecondaryEnd,
                  ] : [
                    AppTheme.lightSecondaryStart,
                    AppTheme.lightSecondaryEnd,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.class_,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.classModel.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.classModel.courseCode,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.school,
                    label: 'Level',
                    value: widget.classModel.level,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.people,
                    label: 'Students',
                    value: _isLoadingCount ? 'Loading...' : '$_studentsCount enrolled',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: 'Created',
                    value: DateFormat('MMMM d, yyyy').format(widget.classModel.createdAt),
                    isDark: isDark,
                  ),
                  if (widget.classModel.code != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.key,
                            color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Class Code',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.classModel.code!,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.classModel.code!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Class code copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 