import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:async';

void main() {
  runApp(const DopamineDetoxApp());
}

// App Blocker Platform Channel
class AppBlocker {
  static const platform = MethodChannel('com.nullpunkt/app_blocker');

  static Future<bool> hasUsagePermission() async {
    try {
      print('Checking usage permission...');
      final bool result = await platform.invokeMethod('hasUsagePermission');
      print('Permission result: $result');
      return result;
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  static Future<void> requestUsagePermission() async {
    try {
      print('Requesting usage permission...');
      await platform.invokeMethod('requestUsagePermission');
      print('Permission request sent');
    } catch (e) {
      print('Error requesting permission: $e');
    }
  }

  static Future<void> startMonitoring(List<String> blockedPackages) async {
    try {
      print('Starting monitoring for ${blockedPackages.length} apps: $blockedPackages');
      await platform.invokeMethod('startMonitoring', {
        'blockedApps': blockedPackages,
      });
      print('Monitoring started successfully');
    } catch (e) {
      print('Error starting monitoring: $e');
    }
  }

  static Future<void> stopMonitoring() async {
    try {
      print('Stopping monitoring...');
      await platform.invokeMethod('stopMonitoring');
      print('Monitoring stopped successfully');
    } catch (e) {
      print('Error stopping monitoring: $e');
    }
  }
}

class DopamineDetoxApp extends StatelessWidget {
  const DopamineDetoxApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StressLess',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isAllBlocked = false;
  DateTime? blockStartTime;
  Duration blockDuration = Duration.zero;
  Timer? _timer;
  List<Map<String, dynamic>> apps = [];
  bool isLoadingApps = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();

    // Update the UI every second when blocked
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isAllBlocked) {
        setState(() {});
      }
    });
  }

  Future<void> _loadInstalledApps() async {
    try {
      List<AppInfo> installedApps = await InstalledApps.getInstalledApps();

      // Filter for social media and browsers (you can customize this list)
      List<String> socialMediaKeywords = [
        'instagram', 'facebook', 'twitter', 'tiktok', 'snapchat',
        'youtube', 'reddit', 'chrome', 'firefox', 'browser', 'whatsapp',
        'telegram', 'messenger', 'discord', 'linkedin', 'pinterest',
        'tumblr', 'twitch', 'spotify', 'netflix', 'edge', 'opera',
        'brave', 'duckduckgo', 'samsung internet'
      ];

      List<Map<String, dynamic>> filteredApps = [];

      for (var app in installedApps) {
        String appName = app.name?.toLowerCase() ?? '';
        String packageName = app.packageName?.toLowerCase() ?? '';

        // Check if app name or package name contains social media keywords
        bool isSocialMedia = socialMediaKeywords.any((keyword) =>
        appName.contains(keyword) || packageName.contains(keyword)
        );

        if (isSocialMedia && app.name != null) {
          filteredApps.add({
            'name': app.name!,
            'packageName': app.packageName ?? '',
            'icon': app.icon,
            'blocked': false,
          });
        }
      }

      // Sort alphabetically
      filteredApps.sort((a, b) => a['name'].compareTo(b['name']));

      setState(() {
        apps = filteredApps;
        isLoadingApps = false;
      });
    } catch (e) {
      print('Error loading apps: $e');
      setState(() {
        isLoadingApps = false;
      });
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    bool hasPermission = await AppBlocker.hasUsagePermission();
    if (!hasPermission && mounted) {
      // Show dialog explaining why permission is needed
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
              'StressLess needs Usage Access permission to monitor and block apps. '
                  'Please enable it in the next screen.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                AppBlocker.requestUsagePermission();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void toggleBlockAll() async {
    // Check permission first
    bool hasPermission = await AppBlocker.hasUsagePermission();
    if (!hasPermission) {
      _checkAndRequestPermissions();
      return;
    }

    setState(() {
      isAllBlocked = !isAllBlocked;
      // Update all individual app blocks
      for (var app in apps) {
        app['blocked'] = isAllBlocked;
      }

      if (isAllBlocked) {
        blockStartTime = DateTime.now();
        // Start monitoring with blocked packages
        List<String> blockedPackages = apps
            .where((app) => app['blocked'] == true)
            .map((app) => app['packageName'] as String)
            .toList();
        AppBlocker.startMonitoring(blockedPackages);
      } else {
        if (blockStartTime != null) {
          blockDuration += DateTime.now().difference(blockStartTime!);
        }
        blockStartTime = null;
        // Stop monitoring
        AppBlocker.stopMonitoring();
      }
    });
  }

  void toggleAppBlock(int index) async {
    bool hasPermission = await AppBlocker.hasUsagePermission();
    if (!hasPermission && !apps[index]['blocked']) {
      _checkAndRequestPermissions();
      return;
    }

    setState(() {
      apps[index]['blocked'] = !apps[index]['blocked'];

      // Update isAllBlocked based on individual app states
      if (apps.isNotEmpty) {
        isAllBlocked = apps.every((app) => app['blocked'] == true);
      }

      // Update monitoring service with new blocked apps
      List<String> blockedPackages = apps
          .where((app) => app['blocked'] == true)
          .map((app) => app['packageName'] as String)
          .toList();

      if (blockedPackages.isNotEmpty) {
        if (isAllBlocked && blockStartTime == null) {
          blockStartTime = DateTime.now();
        }
        AppBlocker.startMonitoring(blockedPackages);
      } else {
        if (blockStartTime != null) {
          blockDuration += DateTime.now().difference(blockStartTime!);
          blockStartTime = null;
        }
        AppBlocker.stopMonitoring();
      }
    });
  }

  String getBlockStatusText() {
    if (isAllBlocked && blockStartTime != null) {
      final duration = DateTime.now().difference(blockStartTime!);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      return 'Blocked for ${hours}h ${minutes}m ${seconds}s';
    } else if (blockDuration.inSeconds > 0) {
      final hours = blockDuration.inHours;
      final minutes = blockDuration.inMinutes % 60;
      final seconds = blockDuration.inSeconds % 60;
      return 'Last session: ${hours}h ${minutes}m ${seconds}s';
    } else {
      return 'Not currently blocking';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                // Black status bar banner
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).padding.top,
                  color: const Color(0xFF000000),
                ),
                // AppBar with profile menu
                Container(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PopupMenuButton<String>(
                          icon: const CircleAvatar(
                            backgroundColor: Color(0xFF2C2C2C),
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                          offset: const Offset(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline, size: 20),
                                  SizedBox(width: 12),
                                  Text('Profile'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'stats',
                              child: Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 20),
                                  SizedBox(width: 12),
                                  Text('Statistics'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(Icons.settings_outlined, size: 20),
                                  SizedBox(width: 12),
                                  Text('Settings'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, size: 20),
                                  SizedBox(width: 12),
                                  Text('Logout'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (String value) {
                            if (value == 'settings') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              );
                            }
                            print('Selected: $value');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Main content area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // App Name/Branding
                        const Text(
                          'StressLess',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 4,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Big Block All Button
                        // Big Block All Button
                        GestureDetector(
                          onTap: toggleBlockAll,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAllBlocked ? const Color(0xFF4CAF50) : const Color(0xFF2C2C2C),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isAllBlocked
                                  ? const Text(
                                'UNBLOCK\nALL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  height: 1.2,
                                ),
                              )
                                  : ClipOval(
                                child: Image.asset(
                                  'assets/block_button_icon.jpg',  // Changed from .png to .jpg
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Status Text
                        Text(
                          getBlockStatusText(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Apps Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Block Individual Apps',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Loading indicator or apps list
                              if (isLoadingApps)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(40.0),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF2C2C2C),
                                    ),
                                  ),
                                )
                              else if (apps.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Text(
                                      'No social media or browser apps found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              else
                              // Apps List
                                ...apps.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  Map<String, dynamic> app = entry.value;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Row(
                                          children: [
                                            // App Icon
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5F5F5),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: app['icon'] != null
                                                  ? ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.memory(
                                                  app['icon'],
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                                  : const Icon(
                                                Icons.apps,
                                                size: 28,
                                                color: Color(0xFF2C2C2C),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // App Name
                                            Expanded(
                                              child: Text(
                                                app['name'],
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF2C2C2C),
                                                ),
                                              ),
                                            ),
                                            // Block Button
                                            ElevatedButton(
                                              onPressed: () => toggleAppBlock(index),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: app['blocked']
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFF2C2C2C),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 12,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: Text(
                                                app['blocked'] ? 'Unblock' : 'Block',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              const SizedBox(height: 100), // Extra space for bottom buttons
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Tasks & Calendar Button (Bottom Left)
            Positioned(
              bottom: 32,
              left: 32,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TasksCalendarScreen()),
                  );
                },
                backgroundColor: const Color(0xFF2C2C2C),
                child: const Icon(Icons.assignment_turned_in, color: Colors.white),
              ),
            ),
            // Settings Button (Bottom Right)
            Positioned(
              bottom: 32,
              right: 32,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                backgroundColor: const Color(0xFF2C2C2C),
                child: const Icon(Icons.settings, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TasksCalendarScreen extends StatefulWidget {
  const TasksCalendarScreen({Key? key}) : super(key: key);

  @override
  State<TasksCalendarScreen> createState() => _TasksCalendarScreenState();
}

class _TasksCalendarScreenState extends State<TasksCalendarScreen> {
  final List<Map<String, dynamic>> lessons = [
    {'name': 'Introduction to Mindfulness', 'isCustom': false},
    {'name': 'Digital Detox Basics', 'isCustom': false},
    {'name': 'Building Healthy Habits', 'isCustom': false},
    {'name': 'Focus and Concentration', 'isCustom': false},
    {'name': 'Time Management Mastery', 'isCustom': false},
    {'name': 'Choose a custom task', 'isCustom': true},
  ];

  void _showCustomTaskDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Custom Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter task name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // Handle custom task assignment
                print('Custom task assigned: ${controller.text}');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task "${controller.text}" assigned!'),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _startTask(String taskName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting task: $taskName'),
        backgroundColor: const Color(0xFF2C2C2C),
      ),
    );
  }

  void _assignTask(String taskName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task "$taskName" assigned!'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            // Black status bar banner
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFF000000),
            ),
            // Custom AppBar
            Container(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Tasks & Calendar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  const Text(
                    'Available Lessons',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Lessons List
                  ...lessons.map((lesson) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Lesson Name
                              Row(
                                children: [
                                  Icon(
                                    lesson['isCustom']
                                        ? Icons.edit_note
                                        : Icons.school,
                                    color: const Color(0xFF2C2C2C),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      lesson['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2C2C2C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Buttons
                              Row(
                                children: [
                                  if (!lesson['isCustom'])
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _startTask(lesson['name']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2C2C2C),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'Start Task',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!lesson['isCustom'])
                                    const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (lesson['isCustom']) {
                                          _showCustomTaskDialog();
                                        } else {
                                          _assignTask(lesson['name']);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4CAF50),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Assign Task',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
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
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double screenTimeLimit = 2.0; // hours
  double blockerTimeLimit = 1.0; // hours
  bool screenTimeLimitEnabled = true;
  bool blockerTimeLimitEnabled = true;
  bool sleepingHoursEnabled = true;

  // Sleep hours in minutes from midnight (0-1439)
  double sleepStartMinutes = 1380.0; // 23:00 (23 * 60)
  double sleepEndMinutes = 420.0; // 07:00 (7 * 60)

  String _formatTime(double minutes) {
    int hours = (minutes ~/ 60);
    int mins = (minutes % 60).toInt();
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  void _uploadSettingsToCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings uploaded to card successfully!'),
        backgroundColor: Color(0xFF4CAF50),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            // Black status bar banner
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFF000000),
            ),
            // Custom AppBar
            Container(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Settings Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  // Upload Settings Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploadSettingsToCard,
                      icon: const Icon(Icons.upload, size: 20),
                      label: const Text(
                        'Upload Settings to Card',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Screen Time Limit Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Daily Screen Time Limit',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C2C2C),
                              ),
                            ),
                            Switch(
                              value: screenTimeLimitEnabled,
                              activeColor: const Color(0xFF4CAF50),
                              onChanged: (value) {
                                setState(() {
                                  screenTimeLimitEnabled = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${screenTimeLimit.toStringAsFixed(1)} hours',
                          style: TextStyle(
                            fontSize: 16,
                            color: screenTimeLimitEnabled ? Colors.grey[600] : Colors.grey[400],
                          ),
                        ),
                        Slider(
                          value: screenTimeLimit,
                          min: 0.5,
                          max: 8.0,
                          divisions: 15,
                          activeColor: screenTimeLimitEnabled ? const Color(0xFF2C2C2C) : Colors.grey[300],
                          inactiveColor: Colors.grey[300],
                          onChanged: screenTimeLimitEnabled ? (value) {
                            setState(() {
                              screenTimeLimit = value;
                            });
                          } : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Blocker Time Limit Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Maximum Block Duration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C2C2C),
                              ),
                            ),
                            Switch(
                              value: blockerTimeLimitEnabled,
                              activeColor: const Color(0xFF4CAF50),
                              onChanged: (value) {
                                setState(() {
                                  blockerTimeLimitEnabled = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${blockerTimeLimit.toStringAsFixed(1)} hours',
                          style: TextStyle(
                            fontSize: 16,
                            color: blockerTimeLimitEnabled ? Colors.grey[600] : Colors.grey[400],
                          ),
                        ),
                        Slider(
                          value: blockerTimeLimit,
                          min: 0.5,
                          max: 6.0,
                          divisions: 11,
                          activeColor: blockerTimeLimitEnabled ? const Color(0xFF2C2C2C) : Colors.grey[300],
                          inactiveColor: Colors.grey[300],
                          onChanged: blockerTimeLimitEnabled ? (value) {
                            setState(() {
                              blockerTimeLimit = value;
                            });
                          } : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sleeping Hours Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sleeping Hours',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C2C2C),
                              ),
                            ),
                            Switch(
                              value: sleepingHoursEnabled,
                              activeColor: const Color(0xFF4CAF50),
                              onChanged: (value) {
                                setState(() {
                                  sleepingHoursEnabled = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From ${_formatTime(sleepStartMinutes)} to ${_formatTime(sleepEndMinutes)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: sleepingHoursEnabled ? Colors.grey[600] : Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Sleep Start Time
                        Text(
                          'Sleep Start: ${_formatTime(sleepStartMinutes)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: sleepingHoursEnabled ? Colors.grey[700] : Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Slider(
                          value: sleepStartMinutes,
                          min: 720.0, // 12:00
                          max: 1439.0, // 23:59
                          divisions: (1439 - 720),
                          activeColor: sleepingHoursEnabled ? const Color(0xFF2C2C2C) : Colors.grey[300],
                          inactiveColor: Colors.grey[300],
                          onChanged: sleepingHoursEnabled ? (value) {
                            setState(() {
                              sleepStartMinutes = value;
                            });
                          } : null,
                        ),
                        const SizedBox(height: 10),
                        // Sleep End Time
                        Text(
                          'Wake Up: ${_formatTime(sleepEndMinutes)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: sleepingHoursEnabled ? Colors.grey[700] : Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Slider(
                          value: sleepEndMinutes,
                          min: 0.0, // 00:00
                          max: 720.0, // 12:00
                          divisions: 720,
                          activeColor: sleepingHoursEnabled ? const Color(0xFF2C2C2C) : Colors.grey[300],
                          inactiveColor: Colors.grey[300],
                          onChanged: sleepingHoursEnabled ? (value) {
                            setState(() {
                              sleepEndMinutes = value;
                            });
                          } : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

