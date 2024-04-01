import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(TaskManagerApp());
}

class Task {
  String subject;
  String description;
  String endTime;
  List<String> tags;

  Task({
    required this.subject,
    required this.description,
    required this.endTime,
    required this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'description': description,
      'endTime': endTime,
      'tags': tags,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      subject: map['subject'],
      description: map['description'],
      endTime: map['endTime'],
      tags: List<String>.from(map['tags']),
    );
  }
}

class TaskManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  late List<Task> notExpiredTasks;
  late List<Task> expiredTasks;
  late TextEditingController _searchController;
  late String _searchBy;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchBy = 'Subject'; // Default search by subject
    loadTasksFromStorage();
  }


  Future<void> loadTasksFromStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskStrings = prefs.getStringList('tasks') ?? [];
    setState(() {
      tasks = taskStrings
          .map((taskString) => Task.fromMap(jsonDecode(taskString)))
          .toList();

      // Filter tasks based on expiry date
      DateTime currentDate = DateTime.now();
      notExpiredTasks =
          tasks.where((task) => DateTime.parse(task.endTime).isAfter(currentDate)).toList();
      expiredTasks =
          tasks.where((task) => DateTime.parse(task.endTime).isBefore(currentDate)).toList();
    });
  }

  Future<void> saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskStrings = tasks.map((task) => jsonEncode(task.toMap())).toList();
    await prefs.setStringList('tasks', taskStrings);
    await loadTasksFromStorage(); // Reload tasks after saving to storage
  }

  void deleteTask(Task task) {
    setState(() {
      tasks.remove(task);
      saveTasks();
    });
  }
  void deleteTaskConfirmation(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Task'),
          content: Text('Are you sure you want to delete this task?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                deleteTask(task); // Delete the task
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }


  void updateTask(Task oldTask, Task newTask) {
    setState(() {
      final index = tasks.indexOf(oldTask);
      if (index != -1) {
        tasks[index] = newTask;
        saveTasks();
      }
    });
  }

  void _setStateCallback() {
    setState(() {});
  }

  void _saveTasksCallback() {
    saveTasks();
  }

  void _searchTasks(String query) {
    List<Task> searchResults;
    if (_searchBy == 'Subject') {
      searchResults = tasks
          .where((task) => task.subject.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } else {
      searchResults = tasks
          .where((task) => task.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    setState(() {
      notExpiredTasks = searchResults
          .where((task) => DateTime.parse(task.endTime).isAfter(DateTime.now()))
          .toList();
      expiredTasks = searchResults
          .where((task) => DateTime.parse(task.endTime).isBefore(DateTime.now()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar:
        AppBar(
          title: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by $_searchBy',
                    border: InputBorder.none,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _searchBy,
                onChanged: (String? newValue) {
                  setState(() {
                    _searchBy = newValue!;
                  });
                },
                items: <String>['Subject', 'Description']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  _searchTasks(_searchController.text);
                },
              ),
            ],
          ),
        )
        ,
        body: TabBarView(
          children: [
            TaskListView(
              tasks: notExpiredTasks,
              setStateCallback: _setStateCallback,
              saveTasksCallback: _saveTasksCallback,
              deleteTaskCallback: deleteTask,
              updateTaskCallback: updateTask,
            ),
            TaskListView(
              tasks: expiredTasks,
              setStateCallback: _setStateCallback,
              saveTasksCallback: _saveTasksCallback,
              deleteTaskCallback: deleteTask,
              updateTaskCallback: updateTask,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTaskScreen(),
              ),
            ).then((value) {
              if (value != null && value is Task) {
                setState(() {
                  tasks.add(value);
                  if (DateTime.parse(value.endTime).isAfter(DateTime.now())) {
                    notExpiredTasks.add(value);
                  } else {
                    expiredTasks.add(value);
                  }
                  saveTasks();
                });
              }
            });
          },


          child: Icon(Icons.add),
        ),

        bottomNavigationBar: Padding(
          padding: EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              saveTasks();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tasks saved successfully.')),
              );
            },
            child: Text('Save Tasks to Local Storage'),
          ),
        ),

      ),
    );
  }
}

class TaskListView extends StatelessWidget {
  final List<Task> tasks;
  final Function() setStateCallback;
  final Function() saveTasksCallback;
  final Function(Task) deleteTaskCallback;
  final Function(Task, Task) updateTaskCallback;

  TaskListView({
    required this.tasks,
    required this.setStateCallback,
    required this.saveTasksCallback,
    required this.deleteTaskCallback,
    required this.updateTaskCallback,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(tasks[index].subject),
          subtitle: Text(tasks[index].description),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailScreen(task: tasks[index]),
              ),
            );
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UpdateTaskScreen(task: tasks[index]),
                    ),
                  ).then((updatedTask) {
                    if (updatedTask != null && updatedTask is Task) {
                      updateTaskCallback(tasks[index], updatedTask);
                      setStateCallback();
                      saveTasksCallback();
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  // Call deleteTaskConfirmation to show confirmation dialog
                  deleteTaskConfirmation(context, tasks[index]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to show delete confirmation dialog
  void deleteTaskConfirmation(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Task'),
          content: Text('Are you sure you want to delete this task?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                deleteTaskCallback(task); // Delete the task
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class TaskDetailScreen extends StatelessWidget {
  final Task task;

  TaskDetailScreen({required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Details'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject: ${task.subject}'),
                SizedBox(height: 8.0),
                Text('Description: ${task.description}'),
                SizedBox(height: 8.0),
                Text('Task End-Time: ${task.endTime}'),
                SizedBox(height: 8.0),
                Text('Tags: ${task.tags.join(', ')}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddTaskScreen extends StatefulWidget {
  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectController;
  late TextEditingController _descriptionController;
  late TextEditingController _endTimeController;
  late TextEditingController _tagsController;
  String _selectedPriority = 'Low';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _descriptionController = TextEditingController();
    _endTimeController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _endTimeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900), // Set the minimum selectable date
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _endTimeController.text = picked.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Task'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(labelText: 'Subject'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _endTimeController,
                onTap: () {
                  _selectDate(context);
                },
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Task End Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a task end date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(labelText: 'Tags'),
              ),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
                items: ['Low', 'Medium', 'High'].map((priority) {
                  return DropdownMenuItem<String>(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                decoration: InputDecoration(labelText: 'Priority'),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Task newTask = Task(
                      subject: _subjectController.text,
                      description: _descriptionController.text,
                      endTime: _endTimeController.text,
                      tags: _tagsController.text.split(','),
                    );
                    Navigator.pop(context, newTask);
                  }
                },
                child: Text('Add Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateTaskScreen extends StatefulWidget {
  final Task task;

  UpdateTaskScreen({required this.task});

  @override
  _UpdateTaskScreenState createState() => _UpdateTaskScreenState();
}

class _UpdateTaskScreenState extends State<UpdateTaskScreen> {
  late TextEditingController _subjectController;
  late TextEditingController _descriptionController;
  late TextEditingController _endTimeController;
  late TextEditingController _tagsController;
  String _selectedPriority = 'Low';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.task.subject);
    _descriptionController =
        TextEditingController(text: widget.task.description);
    _endTimeController = TextEditingController(text: widget.task.endTime);
    _tagsController =
        TextEditingController(text: widget.task.tags.join(', '));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _endTimeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900), // Set the minimum selectable date
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _endTimeController.text = picked.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Task'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(labelText: 'Subject'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _endTimeController,
                onTap: () {
                  _selectDate(context);
                },
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Task End Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a task end date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(labelText: 'Tags'),
              ),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
                items: ['Low', 'Medium', 'High'].map((priority) {
                  return DropdownMenuItem<String>(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                decoration: InputDecoration(labelText: 'Priority'),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  if (_subjectController.text.isNotEmpty &&
                      _descriptionController.text.isNotEmpty &&
                      _endTimeController.text.isNotEmpty) {
                    Task updatedTask = Task(
                      subject: _subjectController.text,
                      description: _descriptionController.text,
                      endTime: _endTimeController.text,
                      tags: _tagsController.text.split(',').map((tag) => tag.trim()).toList(),
                    );
                    Navigator.pop(context, updatedTask);
                  }
                },
                child: Text('Update Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


