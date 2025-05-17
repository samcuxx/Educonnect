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
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../services/supabase_service.dart';

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
  int _studentsCount = 0;
  List<AnnouncementModel> _announcements = [];
  List<ResourceModel> _resources = [];
  DateTime? _lastAnnouncementCheck;
  bool _initialLoadDone = false;
  
  // Add new properties for resource downloads
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadedFiles = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
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
    
    // Load downloaded files info
    _loadDownloadedFiles();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.isLecturer;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.classModel.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.classModel.courseCode} • ${widget.classModel.level}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Announcements'),
            Tab(text: 'Resources'),
          ],
        ),
        actions: [
          // Add action button based on user role
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'leave') {
                _leaveClass();
              } else if (value == 'delete') {
                _deleteClass();
              }
            },
            itemBuilder: (context) => [
              if (isLecturer)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Class'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Leave Class'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      // Add floating action button for lecturers to create announcements or upload resources
      floatingActionButton: isLecturer ? FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _createAnnouncement();
          } else {
            _uploadResource();
          }
        },
        tooltip: _tabController.index == 0 ? 'Add Announcement' : 'Upload Resource',
        child: Icon(_tabController.index == 0 ? Icons.announcement : Icons.upload_file),
      ) : null,
      body: TabBarView(
        controller: _tabController,
            children: [
          // Announcements Tab
          _buildAnnouncementsTab(context, isLecturer),
          
          // Resources Tab
          _buildResourcesTab(context, isLecturer),
        ],
      ),
    );
  }
  
  Widget _buildAnnouncementsTab(BuildContext context, bool isLecturer) {
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      displacement: 40.0,
      color: Theme.of(context).primaryColor,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      child: _isLoadingAnnouncements && _announcements.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _announcements.isEmpty
          ? _buildEmptyState(
              context,
              icon: Icons.announcement,
              title: 'No announcements yet',
              message: isLecturer
                ? 'Tap + to post an announcement for your class'
                : 'Stay tuned for updates from your lecturer',
            )
          : AnimatedList(
              key: GlobalKey<AnimatedListState>(),
              initialItemCount: _announcements.length,
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index, animation) {
                final announcement = _announcements[index];
                return FadeTransition(
                  opacity: animation.drive(CurveTween(curve: Curves.easeIn)),
                  child: SlideTransition(
                    position: animation.drive(Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut))),
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.announcement_outlined,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    announcement.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                announcement.message,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                      child: Text(
                                        announcement.postedByName.substring(0, 1),
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      announcement.postedByName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _getFormattedDate(announcement.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
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
  
  Widget _buildResourcesTab(BuildContext context, bool isLecturer) {
    return RefreshIndicator(
      onRefresh: _loadResources,
      displacement: 40.0,
      color: Theme.of(context).primaryColor,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      child: _isLoadingResources && _resources.isEmpty
        ? const Center(child: CircularProgressIndicator())
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
              padding: const EdgeInsets.all(16),
              itemCount: _resources.length,
              itemBuilder: (context, index) {
                final resource = _resources[index];
                final bool isDownloading = _downloadProgress.containsKey(resource.id);
                final bool isDownloaded = _downloadedFiles.containsKey(resource.id);
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: isDownloaded ? () => _openFile(resource) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getFileColor(resource.fileType).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _getFileIcon(resource.fileType),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      resource.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Uploaded by ${resource.uploadedByName} • ${DateFormat('MMM d, yyyy').format(resource.createdAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Show progress bar if downloading
                          if (isDownloading)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(
                                value: _downloadProgress[resource.id],
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isDownloaded)
                                  TextButton.icon(
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('Open'),
                                    onPressed: () => _openFile(resource),
                                  )
                                else if (isDownloading)
                                  TextButton.icon(
                                    icon: const SizedBox(
                                      width: 16, 
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    label: Text(
                                      '${(_downloadProgress[resource.id]! * 100).toStringAsFixed(0)}%',
                                    ),
                                    onPressed: null,
                                  )
                                else
                                  TextButton.icon(
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text('Download'),
                                    onPressed: () => _downloadFile(resource),
                                  ),
                                
                                const SizedBox(width: 8),
                                
                                // Info button to show file details
                                IconButton(
                                  icon: const Icon(Icons.info_outline, size: 16),
                                  onPressed: () {
                                    _showResourceInfoDialog(context, resource);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
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
    return Center(
                child: Padding(
        padding: const EdgeInsets.all(32),
                  child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
              icon,
              size: 72,
              color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
              title,
                        style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
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
} 