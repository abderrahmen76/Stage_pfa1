import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginForm(),
    );
  }
}

class LoginForm extends StatefulWidget {
  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController serverUrlController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  List<String> databases = [];
  String? selectedDatabase;
  bool isDatabaseDropdownVisible = false;

  @override
  void initState() {
    super.initState();
    serverUrlController.addListener(_onServerUrlChanged);
  }

  void _onServerUrlChanged() {
    if (serverUrlController.text.isNotEmpty) {
      verifyServerUrl();
    } else {
      setState(() {
        isDatabaseDropdownVisible = false;
        databases = [];
        selectedDatabase = null;
      });
    }
  }

  Future<void> verifyServerUrl() async {
    final url = Uri.parse('http://127.0.0.1:5000/login-api');
    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'url': serverUrlController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          databases = List<String>.from(data['databases']);
          isDatabaseDropdownVisible = true;
        });
      } else {
        setState(() {
          isDatabaseDropdownVisible = false;
          databases = [];
          selectedDatabase = null;
        });
        print('Failed to verify server URL: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isDatabaseDropdownVisible = false;
        databases = [];
        selectedDatabase = null;
      });
      print('Error verifying server URL: $e');
    }
  }

  Future<void> sendFormData(BuildContext context) async {
    final url = Uri.parse('http://127.0.0.1:5000/store-data');
    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'url': serverUrlController.text,
          'db': selectedDatabase,
          'username': usernameController.text,
          'password': passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        print('Data sent successfully');
      } else {
        print('Failed to send data: ${response.statusCode}');
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text('Failed to send data: ${response.statusCode}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error sending data: $e');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Error sending data: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }
  Future<void> fetchActiveApps(BuildContext context) async {
  final fetchAppsUrl = Uri.parse('http://127.0.0.1:5000/fetch-apps');
  try {
    final response = await http.get(fetchAppsUrl);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.containsKey('active_apps')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              uid: data['uid'].toString(),
              activeApps: List<String>.from(data['active_apps']),
            ),
          ),
        );
      } else {
        print('Error: active_apps not found in response');
      }
    } else {
      print('Failed to fetch active apps: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching active apps: $e');
  }
}


  Future<void> authenticateAPI(BuildContext context) async {
  // First, send form data
  await sendFormData(context);
  
  // Fetch active apps
  try {
    final url = Uri.parse('http://127.0.0.1:5000/fetch-apps');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['active_apps'] != null && data['active_apps'] is List) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              uid: data['uid'].toString(),
              activeApps: List<String>.from(data['active_apps']),
            ),
          ),
        );
      } else {
        _showErrorDialog(context, 'Invalid response: Active apps list is missing or empty');
      }
    } else {
      _showErrorDialog(context, 'Failed to fetch active apps: ${response.statusCode}');
    }
  } catch (e) {
    _showErrorDialog(context, 'Error fetching active apps: $e');
  }
  
}

void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close'),
          ),
        ],
      );
    },
  );
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login Form'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: serverUrlController,
              decoration: InputDecoration(labelText: 'Server URL'),
            ),
            if (isDatabaseDropdownVisible)
              DropdownButtonFormField<String>(
                value: selectedDatabase,
                onChanged: (newValue) {
                  setState(() {
                    selectedDatabase = newValue;
                  });
                },
                items: databases.map<DropdownMenuItem<String>>((String db) {
                  return DropdownMenuItem<String>(
                    value: db,
                    child: Text(db),
                  );
                }).toList(),
                decoration: InputDecoration(labelText: 'Database'),
              ),
            TextFormField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => authenticateAPI(context),
              child: Text('Authenticate API'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final String uid;
  final List<String> activeApps;

  HomePage({required this.uid, required this.activeApps});

  @override
  Widget build(BuildContext context) {
    
    print('Active Apps: $activeApps');

    // Define icons and labels based on active apps
    Map<String, IconData> appIcons = {
      'project': Icons.work,
      //'crm': Icons.people,
      'contacts': Icons.contact_phone,
      'hr_timesheet': Icons.access_time,
    };

    Map<String, String> appLabels = {
      'project': 'Project',
      //'crm': 'CRM',
      'contacts': 'Contacts',
      'hr_timesheet': 'Timesheet',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to Home Page!'),
            SizedBox(height: 20),
            // Display icons and labels for active apps in a row
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20.0, // spacing between icons
              runSpacing: 20.0, // spacing between rows
              children: appIcons.keys.map((appName) {
                if (activeApps.contains(appName)) {
                  return GestureDetector(
                    onTap: () => _onAppIconTap(context, appName),
                    child: _buildAppIcon(appName, appIcons[appName]!, appLabels[appName]!),
                  );
                } else {
                  return SizedBox.shrink(); // Placeholder for inactive apps
                }
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(String appName, IconData iconData, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          iconData,
          size: 48,
          color: Colors.blue,
        ),
        SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  void _onAppIconTap(BuildContext context, String appName) async {
    // Handle navigation based on app name
    switch (appName) {
      case 'project':
        await _fetchAndNavigateToTaskPage(context);
        break;
      case 'contacts':
        await _fetchAndNavigateToContactPages(context);
        break;
      case 'hr_timesheet':
        await _fetchAndNavigateTotimePages(context);
        break;
      // Add cases for other apps as needed
      default:
        break;
    }
  }

  Future<void> _fetchAndNavigateToTaskPage(BuildContext context) async {
  final authenticateUrl = Uri.parse('http://127.0.0.1:5000/authenticate-api');
  final fetchTasksUrl = Uri.parse('http://127.0.0.1:5000/fetch-tasks');

  try {
    // Authenticate to get the uid
    final authResponse = await http.get(authenticateUrl);
    if (authResponse.statusCode == 200) {
      final authData = jsonDecode(authResponse.body);
      final uid = authData['uid'];  // Extracting the uid from the response
      print('UID fetched: $uid');

      // Fetch tasks with the authenticated uid
      final tasksResponse = await http.get(fetchTasksUrl);
      if (tasksResponse.statusCode == 200) {
        final tasksData = jsonDecode(tasksResponse.body);
        print('Tasks fetched: ${tasksData.length}');

        // Navigate to TaskPage with uid
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TaskPage(uid: uid.toString()),
          ),
        );
      } else {
        print('Failed to fetch tasks: ${tasksResponse.statusCode}');
        // Handle error
      }
    } else {
      print('Failed to authenticate: ${authResponse.statusCode}');
      // Handle error
    }
  } catch (e) {
    print('Error: $e');
    // Handle error
  }
}

Future<void> _fetchAndNavigateToContactPages(BuildContext context) async {
  final authenticateUrl = Uri.parse('http://127.0.0.1:5000/authenticate-api');
  final fetchcntsUrl = Uri.parse('http://127.0.0.1:5000/fetch-contacts');

  try {
    // Authenticate to get the uid
    final authResponse = await http.get(authenticateUrl);
    if (authResponse.statusCode == 200) {
      final authData = jsonDecode(authResponse.body);
      final uid = authData['uid'];  // Extracting the uid from the response
      print('UID fetched: $uid');
      // Fetch contacts with the authenticated uid
      final cntResponse = await http.get(fetchcntsUrl);
      if (cntResponse.statusCode == 200) {
        final cntData = jsonDecode(cntResponse.body);
        print('contact fetched: ${cntData.length}');

        // Navigate to contactpage with uid
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ContactPages(),
          ),
        );
      } else {
        print('Failed to fetch contacts: ${cntResponse.statusCode}');
        // Handle error
      }
    } else {
      print('Failed to authenticate: ${authResponse.statusCode}');
      // Handle error
    }
  } catch (e) {
    print('Error: $e');
    // Handle error
  }
}
Future<void> _fetchAndNavigateTotimePages(BuildContext context) async {
  final authenticateUrl = Uri.parse('http://127.0.0.1:5000/authenticate-api');
  final fetchtssUrl = Uri.parse('http://127.0.0.1:5000/fetch-timesheet');

  try {
    // Authenticate to get the uid
    final authResponse = await http.get(authenticateUrl);
    if (authResponse.statusCode == 200) {
      final authData = jsonDecode(authResponse.body);
      final uid = authData['uid'];  // Extracting the uid from the response
      print('UID fetched: $uid');

      // Fetch timesheet with the authenticated uid
      final tsResponse = await http.get(fetchtssUrl);
      if (tsResponse.statusCode == 200) {
        final tsData = jsonDecode(tsResponse.body);
        print('timesheets fetched: ${tsData.length}');

        // Navigate to TimePages with the fetched tasks
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TimePage(), // Pass the fetched data here
          ),
        );
      } else {
        print('Failed to fetch timesheets: ${tsResponse.statusCode}');
        // Handle error
      }
    } else {
      print('Failed to authenticate: ${authResponse.statusCode}');
      // Handle error
    }
  } catch (e) {
    print('Error: $e');
    // Handle error
  }
}


}


class TaskPage extends StatelessWidget {
  final String uid;

  TaskPage({required this.uid});

  Future<List<dynamic>> fetchTasks() async {
    final authenticateUrl = Uri.parse('http://127.0.0.1:5000/authenticate-api');
    final authResponse = await http.get(authenticateUrl);
    final authData = jsonDecode(authResponse.body);
    final uid = authData['uid'];

    final url = Uri.parse('http://127.0.0.1:5000/fetch-tasks?uid=$uid');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    void navigateToHomePage(BuildContext context) async{
      final fetchAppsUrl = Uri.parse('http://127.0.0.1:5000/fetch-apps');
      final authenticateUrl = Uri.parse('http://127.0.0.1:5000/authenticate-api');
      try {
        final authResponse = await http.get(authenticateUrl);
        final response = await http.get(fetchAppsUrl);
        if (response.statusCode == 200 && authResponse.statusCode == 200) {
          final authData = jsonDecode(authResponse.body);
          final uid = authData['uid'];
          final data = jsonDecode(response.body);
          if (data.containsKey('active_apps')) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  uid: uid.toString(),
                  activeApps: List<String>.from(data['active_apps']),
                ),
              ),
            );
          } else {
            print('Error: active_apps not found in response');
          }
        } else {
          print('Failed to fetch active apps: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching active apps: $e');
      }
    }
    void addTask(BuildContext context) async {
  final isadminurl = Uri.parse('http://127.0.0.1:5000/isadmin');
  
  try {
    final isadminresponse = await http.get(isadminurl);

    if (isadminresponse.statusCode == 200) {
      final isadmindata = jsonDecode(isadminresponse.body);
      final isAdmin = isadmindata['is_admin'];

      if (isAdmin) {
        // Navigate to the add task page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddTaskPage()),
        );
      } else {
        // Show a popup message
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Permission Error"),
              content: Text("You must be an admin to add tasks."),
              actions: <Widget>[
                TextButton(
                  child: Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      print('Failed to check admin status: ${isadminresponse.statusCode}');
      // Handle error case if needed
    }
  } catch (e) {
    print('Error checking admin: $e');
    // Handle error case if needed
  }
}
    print('TaskPage UID: $uid');
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks'),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 10.0), // Adjust margin as needed
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red, // Replace with your desired background color
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.white), // Customize icon color
              onPressed: () {
                addTask(context);
              },
            ),
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            navigateToHomePage(context);
          },
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No tasks found.'));
          } else {
            final tasks = snapshot.data!;
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(
                  task: task,
                  onStageUpdated: () {
                    // Trigger a rebuild to refresh the task list
                    (context as Element).reassemble();
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

class TaskCard extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onStageUpdated;

  // Define activity icons mapping
  static const Map<String, IconData> activityIcons = {
    'Call': Icons.phone,
    'Email': Icons.email,
    'Meeting': Icons.event,
    // Add more mappings as needed
  };

  TaskCard({required this.task, required this.onStageUpdated});

  @override
  _TaskCardState createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late String selectedStage; // Mark as late

  int findStageId(String selectedStage, List<String> stages) {
    int index = stages.indexOf(selectedStage);
    if (index != -1) {
      return index + 1; // Assuming stage IDs start from 1
    } else {
      return 1; // Default stage ID or handle null case as per your logic
    }
  }

  Future<void> updateTaskStage(int taskId, String newStagename) async {
    String url = 'http://127.0.0.1:5000/update-stage';

    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    Map<String, dynamic> data = {
      'task_id': taskId,
      'new_stage_name': newStagename,
    };
    // Convert data to JSON string
    String body = json.encode(data);
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        print('Stage updated successfully');
        widget.onStageUpdated(); // Trigger the callback to refresh the task list
      } else {
        print('Failed to update stage: ${response.body}');
      }
    } catch (e) {
      print('Error updating stage: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    selectedStage = widget.task['stage_id'][1] ?? 'No stage'; // Initialize in initState
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${widget.task['name'] ?? 'No name'}: $selectedStage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // Three-dot menu in top-right corner
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  itemBuilder: (BuildContext context) {
                    List<String>? stages = widget.task['stages']?.cast<String>();
                    if (stages != null) {
                      return stages.map((stage) {
                        return PopupMenuItem<String>(
                          value: stage,
                          child: Text(stage),
                        );
                      }).toList();
                    }
                    return [];
                  },
                  onSelected: (String selectedStage) async {
                    setState(() {
                      this.selectedStage = selectedStage;
                    });
                    await updateTaskStage(widget.task['id'], selectedStage); // Pass selectedStage (name) instead of ID
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('${widget.task['project_id']?[1] ?? 'No project'}'),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.local_offer, size: 16, color: Colors.grey),
                SizedBox(width: 5),
                if (widget.task['tag_names'] != null && widget.task['tag_names'] is List) ...[
                  ...List<String>.from(widget.task['tag_names']).map((tagName) {
                    return _buildTagChip(tagName);
                  }).toList(),
                ],
              ],
            ),
            SizedBox(height: 8),
            Text(_buildDeadlineText(), style: TextStyle(color: _buildDeadlineColor())),
            SizedBox(height: 5),
            _buildRemainingHoursAndPriorityWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingHoursAndPriorityWidget() {
    double remainingHours = widget.task['remaining_hours'] ?? 0.0;
    String formattedHours = remainingHours.toStringAsFixed(2);

    List<Widget> activityIconsWidgets = [];

    List<dynamic>? activities = widget.task['activities'];
    if (activities != null && activities.isNotEmpty) {
      activityIconsWidgets.addAll(
        activities.map<Widget>((activity) {
          if (activity['activity_type_id'] != null && activity['activity_type_id'].length > 1) {
            String activityType = activity['activity_type_id'][1];
            if (TaskCard.activityIcons.containsKey(activityType)) {
              return Icon(
                TaskCard.activityIcons[activityType],
                size: 20,
                color: Colors.blue, // Adjust color as needed
              );
            }
          }
          return Container();
        }).toList(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              _buildPriorityIcon(),
              size: 24,
              color: _buildPriorityColor(),
            ),
            SizedBox(width: 5),
            if (remainingHours > 0)
              Container(
                width: 60,
                height: 24,
                margin: EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    formattedHours,
                    style: TextStyle(color: Colors.black, fontSize: 12),
                  ),
                ),
              ),
            SizedBox(width: 10),
            ...activityIconsWidgets,
          ],
        ),
        _buildKanbanStateCircle(),
      ],
    );
  }

  Widget _buildKanbanStateCircle() {
    Color stateColor;

    switch (widget.task['kanban_state']) {
      case 'done':
        stateColor = Colors.green;
        break;
      case 'blocked':
        stateColor = Colors.red;
        break;
      case 'normal':
      default:
        stateColor = Colors.grey;
        break;
    }

    return Container(
      width: 20,
      height: 20,
      margin: EdgeInsets.only(bottom: 8, right: 8),
      decoration: BoxDecoration(
        color: stateColor,
        shape: BoxShape.circle,
      ),
    );
  }

  IconData _buildPriorityIcon() {
    IconData priorityIcon;
    switch (widget.task['priority']) {
      case '1':
        priorityIcon = Icons.star;
        break;
      case '0':
      default:
        priorityIcon = Icons.star_border;
        break;
    }
    return priorityIcon;
  }

  Color _buildPriorityColor() {
    Color priorityColor;
    switch (widget.task['priority']) {
      case '1':
        priorityColor = Colors.yellow;
        break;
      case '0':
      default:
        priorityColor = Colors.grey;
        break;
    }
    return priorityColor;
  }

  String _buildDeadlineText() {
    if (widget.task['date_deadline'] == null || widget.task['date_deadline'] is! String) {
      return 'No deadline';
    }
    DateTime deadline;
    try {
      deadline = DateTime.parse(widget.task['date_deadline']);
    } catch (e) {
      return 'Invalid deadline';
    }
    DateTime now = DateTime.now();
    int differenceInDays = deadline.difference(now).inDays;

    String deadlineText;
    if (differenceInDays > 0) {
      deadlineText = 'in $differenceInDays days';
    } else if (differenceInDays == 0) {
      deadlineText = 'today';
    } else {
      deadlineText = '${-differenceInDays} days ago';
    }
    return deadlineText;
  }

  Color _buildDeadlineColor() {
    if (widget.task['date_deadline'] == null || widget.task['date_deadline'] is! String) {
      return Colors.grey;
    }
    DateTime deadline;
    try {
      deadline = DateTime.parse(widget.task['date_deadline']);
    } catch (e) {
      return Colors.grey;
    }
    DateTime now = DateTime.now();
    int differenceInDays = deadline.difference(now).inDays;

    Color deadlineColor;
    if (differenceInDays > 0) {
      deadlineColor = Colors.green;
    } else if (differenceInDays == 0) {
      deadlineColor = Colors.grey;
    } else {
      deadlineColor = Colors.red;
    }
    return deadlineColor;
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: Colors.purple[100],
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 12, color: Colors.purple),
      ),
    );
  }
}
class AddTaskPage extends StatefulWidget {
  @override
  _AddTaskPageState createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  List<String> projectNames = [];
  Map<String, List<String>> projectStages = {};
  List<String> userNames = [];

  String? selectedProject;
  String? selectedUser;
  String? selectedStage;
  String priority = '0'; // Initialize with default value '0'
  String taskName = '';
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    fetchTaskData();
  }

  Future<void> fetchTaskData() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:5000/fetch-new-task'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('Fetched Data: $data');

        if (data != null && data.containsKey('projects') && data.containsKey('users')) {
          setState(() {
            projectNames = List<String>.from(data['projects'].map((project) => project['Project']));
            projectStages = {
              for (var project in data['projects'])
                project['Project']: List<String>.from(project['Stages'])
            };
            userNames = List<String>.from(data['users'].map((user) => user['name']));
          });

          print('Project Names: $projectNames');
          print('Project Stages: $projectStages');
          print('User Names: $userNames');
        } else {
          print('Data is null or missing keys');
        }
      } else {
        print('Failed to load task data, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching task data: $e');
    }
  }

  Future<void> addTask() async {
  if (selectedProject == null || selectedUser == null || selectedStage == null) {
    print('One or more fields are null');
    return;
  }

  // Debug logs before making the request
  print('Task Name: $taskName');
  print('Project Name: $selectedProject');
  print('Stage Name: $selectedStage');
  print('User Name: $selectedUser');
  print('Priority: $priority');
  print('Deadline: ${selectedDate != null ? selectedDate!.toIso8601String() : null}');

  try {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/add-task'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'task_name': taskName,
        'project_name': selectedProject, // Send project name
        'stage_name': selectedStage,     // Send stage name
        'user_name': selectedUser,       // Send user name
        'priority': priority,
        'deadline': selectedDate != null ? selectedDate!.toIso8601String() : null
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        print('Task added successfully');
        Navigator.pop(context);
      } else {
        print('Failed to add task: ${data['error']}');
      }
    } else {
      print('Failed to add task, status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error adding task: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Task'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: addTask,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Task Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  taskName = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Project Name',
                border: OutlineInputBorder(),
              ),
              items: projectNames.map((project) {
                return DropdownMenuItem(
                  child: Text(project),
                  value: project,
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedProject = value;
                  selectedStage = null; // Reset selected stage when project changes
                });
              },
              value: selectedProject,
            ),
            SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Assigned To',
                border: OutlineInputBorder(),
              ),
              items: userNames.map((user) {
                return DropdownMenuItem(
                  child: Text(user),
                  value: user,
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedUser = value;
                });
              },
              value: selectedUser,
            ),
            SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Stage Name',
                border: OutlineInputBorder(),
              ),
              items: selectedProject != null
                  ? (projectStages[selectedProject]!
                      .toSet() // Convert to Set to remove duplicates
                      .toList() // Convert back to List
                      ..sort()) // Optionally sort if needed
                      .map((stage) {
                        return DropdownMenuItem(
                          child: Text(stage),
                          value: stage,
                        );
                      }).toList()
                  : [],
              onChanged: (value) {
                setState(() {
                  selectedStage = value;
                });
                print('Unique stages for $selectedProject: ${projectStages[selectedProject]!.toSet().toList()}');
              },
              value: selectedStage,
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Checkbox(
                  value: priority == '1',
                  onChanged: (value) {
                    setState(() {
                      priority = value == true ? '1' : '0'; // Set priority to '1' or '0'
                    });
                  },
                ),
                Text('High Priority'),
              ],
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null && picked != selectedDate)
                  setState(() {
                    selectedDate = picked;
                  });
              },
              child: Text(selectedDate != null ? 'Deadline: ${selectedDate!.toLocal()}'.split(' ')[0] : 'Select Deadline'),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactPages extends StatefulWidget {
  @override
  _ContactPagesState createState() => _ContactPagesState();
}

class _ContactPagesState extends State<ContactPages> {
  List<dynamic> contacts = [];

  @override
  void initState() {
    super.initState();
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:5000/fetch-contacts'));

    if (response.statusCode == 200) {
      setState(() {
        contacts = json.decode(response.body);
      });
    } else {
      // Handle errors
      print('Failed to load contacts');
    }
  }

  @override
  Widget build(BuildContext context) {
    void navigateToHomePage(BuildContext context) async{
      final fetchAppsUrl = Uri.parse('http://127.0.0.1:5000/fetch-apps');
      final authenticateUrl = Uri.parse('http://127.0.0.1:5000/authenticate-api');
      try {
        final authResponse = await http.get(authenticateUrl);
        final response = await http.get(fetchAppsUrl);
        if (response.statusCode == 200 && authResponse.statusCode == 200) {
          final authData = jsonDecode(authResponse.body);
          final uid = authData['uid'];
          final data = jsonDecode(response.body);
          if (data.containsKey('active_apps')) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  uid: uid.toString(),
                  activeApps: List<String>.from(data['active_apps']),
                ),
              ),
            );
          } else {
            print('Error: active_apps not found in response');
          }
        } else {
          print('Failed to fetch active apps: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching active apps: $e');
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            navigateToHomePage(context);
          },
        ),
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final imageProvider = contact['image_1920'] != null
              ? MemoryImage(base64Decode(contact['image_1920']))
              : AssetImage('assets/unknown_profile.png') as ImageProvider;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: imageProvider,
                backgroundColor: Colors.grey[200],
              ),
              title: Text(contact['name'] ?? 'No Name'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: ${contact['email'] ?? 'N/A'}'),
                  if (contact['phone'] != null) Text('Phone: ${contact['phone']}'),
                  if (contact['mobile'] != null) Text('Mobile: ${contact['mobile']}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TimePage extends StatefulWidget {
  @override
  _TimePageState createState() => _TimePageState();
}
class _TimePageState extends State<TimePage> {
  Future<List<Map<String, dynamic>>>? _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = fetchTasks();
  }

  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:5000/fetch-timesheet'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    void navigateToHomePage(BuildContext context) async{
      final fetchAppsUrl = Uri.parse('http://127.0.0.1:5000/fetch-apps');
      final authenticateUrl = Uri.parse('http://127.0.0.1:5000/authenticate-api');
      try {
        final authResponse = await http.get(authenticateUrl);
        final response = await http.get(fetchAppsUrl);
        if (response.statusCode == 200 && authResponse.statusCode == 200) {
          final authData = jsonDecode(authResponse.body);
          final uid = authData['uid'];
          final data = jsonDecode(response.body);
          if (data.containsKey('active_apps')) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  uid: uid.toString(),
                  activeApps: List<String>.from(data['active_apps']),
                ),
              ),
            );
          } else {
            print('Error: active_apps not found in response');
          }
        } else {
          print('Failed to fetch active apps: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching active apps: $e');
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks and Timesheets'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            navigateToHomePage(context);
          },
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No tasks found'));
          } else {
            final tasks = snapshot.data!;
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(task['name']),
                    subtitle: Text('Timesheets: ${task['timesheet_lines'].length}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChronoPage(task: task),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class ChronoPage extends StatefulWidget {
  final Map<String, dynamic> task;

  ChronoPage({required this.task});

  @override
  _ChronoPageState createState() => _ChronoPageState();
}

class _ChronoPageState extends State<ChronoPage> with WidgetsBindingObserver {
  late Stopwatch _stopwatch;
  Timer? _timer;
  bool _isRunning = false;
  int _savedElapsedMilliseconds = 0;
  DateTime? _lastPauseTime;

  String get _taskKey => 'elapsedTime_${widget.task['id']}'; // Unique key for each task

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopwatch = Stopwatch();
    _restoreElapsedTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_stopwatch.isRunning) {
      _pauseStopwatch();
      _saveElapsedTime();
    }
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return; // Check if widget is still mounted

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_stopwatch.isRunning) {
        _pauseStopwatch();
        _saveElapsedTime();
      }
    } else if (state == AppLifecycleState.resumed) {
      _restoreElapsedTime();
    }
  }

  Future<void> _saveElapsedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final elapsedMilliseconds = _stopwatch.elapsedMilliseconds + _savedElapsedMilliseconds;
    await prefs.setInt(_taskKey, elapsedMilliseconds);
    if (mounted) {
      print('Elapsed time for task ${widget.task['id']} saved: $elapsedMilliseconds ms');
    }
  }

  Future<void> _restoreElapsedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMilliseconds = prefs.getInt(_taskKey) ?? 0;
    if (mounted) {
      setState(() {
        _savedElapsedMilliseconds = savedMilliseconds;
        if (_stopwatch.isRunning) {
          _lastPauseTime = DateTime.now();
        }
      });
      print('Elapsed time for task ${widget.task['id']} restored: $savedMilliseconds ms');
    }
  }

  void _startStopwatch() {
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _stopwatch.start();
      _isRunning = true;
      if (_lastPauseTime != null) {
        _savedElapsedMilliseconds += DateTime.now().difference(_lastPauseTime!).inMilliseconds;
        _lastPauseTime = null;
      }
    });
    _timer = Timer.periodic(Duration(milliseconds: 100), (Timer timer) {
      if (!_stopwatch.isRunning) {
        timer.cancel();
      }
      if (mounted) {
        setState(() {}); // Trigger rebuild to update the timer display
      }
    });
  }

  void _pauseStopwatch() {
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _stopwatch.stop();
      _isRunning = false;
      if (_stopwatch.isRunning) {
        _lastPauseTime = DateTime.now();
      }
    });
    _saveElapsedTime(); // Save the elapsed time when paused
    _timer?.cancel();
  }

  void _resetStopwatch() {
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _stopwatch.reset();
      _isRunning = false;
      _savedElapsedMilliseconds = 0;
      _lastPauseTime = null;
    });
    _saveElapsedTime(); // Ensure the reset time is saved
  }

  Future<void> _onCheckPressed() async {
    final unitAmount = (_savedElapsedMilliseconds + _stopwatch.elapsedMilliseconds) / 3600000.0;
    String timesheetName = await _showInputDialog();

    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/add-timesheet-line'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'task_id': widget.task['id'],
        'unit_amount': unitAmount,
        'name': timesheetName,
        'date': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      print('Timesheet line added successfully');
    } else {
      print('Failed to add timesheet line');
    }

    _resetStopwatch(); // Reset the stopwatch after adding a timesheet line
  }

  Future<String> _showInputDialog() async {
    String input = '';
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Timesheet Line Name'),
          content: TextField(
            onChanged: (value) {
              input = value;
            },
            decoration: InputDecoration(hintText: "Timesheet Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(input);
              },
            ),
          ],
        );
      },
    );
    return input;
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = twoDigits(duration.inMilliseconds.remainder(1000) ~/ 10);
    return "$minutes:$seconds.$milliseconds";
  }

  Future<bool> _onWillPop() async {
    if (_stopwatch.isRunning) {
      _pauseStopwatch();
      await _saveElapsedTime();
    }
    return true; // Allow the back navigation
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = Duration(milliseconds: _savedElapsedMilliseconds + _stopwatch.elapsedMilliseconds);
    final timesheetLines = widget.task['timesheet_lines'] as List<dynamic>;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chrono Page'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              if (_stopwatch.isRunning) {
                _pauseStopwatch();
                await _saveElapsedTime();
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.check),
              onPressed: _onCheckPressed,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Task Name: ${widget.task['name']}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'Chronometer:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatTime(elapsed),
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isRunning ? null : _startStopwatch,
                    child: Text('Play'),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: !_isRunning ? null : _pauseStopwatch,
                    child: Text('Pause'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text('Timesheets:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              if (timesheetLines.isEmpty)
                Center(child: Text('No timesheets available'))
              else
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      columns: [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Hours')),
                        DataColumn(label: Text('Date')),
                      ],
                      rows: timesheetLines.map<DataRow>((timesheet) {
                        return DataRow(
                          cells: [
                            DataCell(Text(timesheet['name'])),
                            DataCell(Text(timesheet['unit_amount'].toString())),
                            DataCell(Text(timesheet['date'])),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
