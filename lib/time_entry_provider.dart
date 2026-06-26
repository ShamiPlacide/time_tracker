import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------
/// MODELS
/// ---------------------------------------------------------------------

class Project {
  String id;
  String name;
  String description;

  Project({
    required this.id,
    required this.name,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
      );
}

class Task {
  String id;
  String projectId;
  String title;
  bool isCompleted;

  Task({
    required this.id,
    required this.projectId,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        title: json['title'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

class TimeEntry {
  String id;
  String projectId;
  String? taskId;
  DateTime date;
  int durationMinutes;
  String note;

  TimeEntry({
    required this.id,
    required this.projectId,
    this.taskId,
    required this.date,
    required this.durationMinutes,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'taskId': taskId,
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'note': note,
      };

  factory TimeEntry.fromJson(Map<String, dynamic> json) => TimeEntry(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        taskId: json['taskId'] as String?,
        date: DateTime.parse(json['date'] as String),
        durationMinutes: json['durationMinutes'] as int,
        note: json['note'] as String? ?? '',
      );
}

/// ---------------------------------------------------------------------
/// PROVIDER
/// ---------------------------------------------------------------------

/// Handles all app state (projects, tasks, time entries) and persists
/// everything locally using shared_preferences so data survives the
/// app being closed and reopened.
class TimeEntryProvider extends ChangeNotifier {
  static const String _projectsKey = 'projects_data';
  static const String _tasksKey = 'tasks_data';
  static const String _timeEntriesKey = 'time_entries_data';

  List<Project> _projects = [];
  List<Task> _tasks = [];
  List<TimeEntry> _timeEntries = [];

  bool _isLoading = true;

  List<Project> get projects => List.unmodifiable(_projects);
  List<Task> get tasks => List.unmodifiable(_tasks);
  List<TimeEntry> get timeEntries => List.unmodifiable(_timeEntries);
  bool get isLoading => _isLoading;

  TimeEntryProvider() {
    _loadAllData();
  }

  /// -------------------------------------------------------------
  /// LOADING
  /// -------------------------------------------------------------

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    final projectsString = prefs.getString(_projectsKey);
    if (projectsString != null) {
      final List<dynamic> decoded = jsonDecode(projectsString);
      _projects = decoded.map((e) => Project.fromJson(e)).toList();
    }

    final tasksString = prefs.getString(_tasksKey);
    if (tasksString != null) {
      final List<dynamic> decoded = jsonDecode(tasksString);
      _tasks = decoded.map((e) => Task.fromJson(e)).toList();
    }

    final timeEntriesString = prefs.getString(_timeEntriesKey);
    if (timeEntriesString != null) {
      final List<dynamic> decoded = jsonDecode(timeEntriesString);
      _timeEntries = decoded.map((e) => TimeEntry.fromJson(e)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// -------------------------------------------------------------
  /// SAVING (private helpers, one per collection)
  /// -------------------------------------------------------------

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await prefs.setString(_projectsKey, encoded);
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_tasksKey, encoded);
  }

  Future<void> _saveTimeEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_timeEntries.map((te) => te.toJson()).toList());
    await prefs.setString(_timeEntriesKey, encoded);
  }

  /// -------------------------------------------------------------
  /// PROJECT CRUD
  /// -------------------------------------------------------------

  Future<void> addProject(Project project) async {
    _projects.add(project);
    notifyListeners();
    await _saveProjects();
  }

  Future<void> updateProject(Project updatedProject) async {
    final index = _projects.indexWhere((p) => p.id == updatedProject.id);
    if (index != -1) {
      _projects[index] = updatedProject;
      notifyListeners();
      await _saveProjects();
    }
  }

  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((p) => p.id == projectId);

    // Cascade delete: remove tasks and time entries tied to this project
    _tasks.removeWhere((t) => t.projectId == projectId);
    _timeEntries.removeWhere((te) => te.projectId == projectId);

    notifyListeners();
    await _saveProjects();
    await _saveTasks();
    await _saveTimeEntries();
  }

  Project? getProjectById(String id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// -------------------------------------------------------------
  /// TASK CRUD
  /// -------------------------------------------------------------

  Future<void> addTask(Task task) async {
    _tasks.add(task);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> updateTask(Task updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
      await _saveTasks();
    }
  }

  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    // Don't delete time entries tied to this task -- taskId is now
    // optional on TimeEntry, so just clear the reference instead of
    // destroying the user's logged time.
    for (final te in _timeEntries) {
      if (te.taskId == taskId) {
        te.taskId = null;
      }
    }

    notifyListeners();
    await _saveTasks();
    await _saveTimeEntries();
  }

  List<Task> getTasksForProject(String projectId) {
    return _tasks.where((t) => t.projectId == projectId).toList();
  }

  Task? getTaskById(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// -------------------------------------------------------------
  /// TIME ENTRY CRUD
  /// -------------------------------------------------------------

  Future<void> addTimeEntry(TimeEntry entry) async {
    _timeEntries.add(entry);
    notifyListeners();
    await _saveTimeEntries();
  }

  Future<void> updateTimeEntry(TimeEntry updatedEntry) async {
    final index = _timeEntries.indexWhere((te) => te.id == updatedEntry.id);
    if (index != -1) {
      _timeEntries[index] = updatedEntry;
      notifyListeners();
      await _saveTimeEntries();
    }
  }

  Future<void> deleteTimeEntry(String entryId) async {
    _timeEntries.removeWhere((te) => te.id == entryId);
    notifyListeners();
    await _saveTimeEntries();
  }

  /// -------------------------------------------------------------
  /// AGGREGATES / HELPERS
  /// -------------------------------------------------------------

  /// Total minutes tracked across all entries.
  int get totalMinutesTracked =>
      _timeEntries.fold(0, (sum, te) => sum + te.durationMinutes);

  /// Total minutes tracked for a single project.
  int totalMinutesForProject(String projectId) {
    return _timeEntries
        .where((te) => te.projectId == projectId)
        .fold(0, (sum, te) => sum + te.durationMinutes);
  }

  /// Time entries sorted most-recent first.
  List<TimeEntry> get recentTimeEntries {
    final sorted = List<TimeEntry>.from(_timeEntries);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
}
