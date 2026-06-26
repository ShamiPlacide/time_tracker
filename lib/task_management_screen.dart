import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'time_entry_provider.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  // null means "All Projects" filter
  String? _filterProjectId;

  void _showTaskDialog(BuildContext context, {Task? existingTask}) {
    final provider = Provider.of<TimeEntryProvider>(context, listen: false);
    final projects = provider.projects;

    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a project first before adding tasks.'),
        ),
      );
      return;
    }

    final titleController =
        TextEditingController(text: existingTask?.title ?? '');
    final formKey = GlobalKey<FormState>();
    final isEditing = existingTask != null;
    String? selectedProjectId =
        existingTask?.projectId ?? _filterProjectId ?? projects.first.id;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Task' : 'New Task'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedProjectId,
                      decoration: const InputDecoration(labelText: 'Project'),
                      items: projects
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedProjectId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      autofocus: true,
                      decoration:
                          const InputDecoration(labelText: 'Task Title'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedProjectId == null) return;

                    if (isEditing) {
                      provider.updateTask(
                        Task(
                          id: existingTask.id,
                          projectId: selectedProjectId!,
                          title: titleController.text.trim(),
                          isCompleted: existingTask.isCompleted,
                        ),
                      );
                    } else {
                      provider.addTask(
                        Task(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          projectId: selectedProjectId!,
                          title: titleController.text.trim(),
                        ),
                      );
                    }

                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Task?'),
          content: Text(
            'This will permanently delete "${task.title}" along with '
            'all its time entries. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<TimeEntryProvider>(context, listen: false)
                    .deleteTask(task.id);
                Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tasks')),
      body: Consumer<TimeEntryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final projects = provider.projects;
          final tasks = _filterProjectId == null
              ? provider.tasks
              : provider.getTasksForProject(_filterProjectId!);

          return Column(
            children: [
              if (projects.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String?>(
                      value: _filterProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Project',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Projects'),
                        ),
                        ...projects.map((p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(p.name),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _filterProjectId = value);
                      },
                    ),
                  ),
                ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.checklist_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'No tasks yet',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the button below to add a task.',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final project =
                              provider.getProjectById(task.projectId);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: Checkbox(
                                value: task.isCompleted,
                                onChanged: (value) {
                                  provider.updateTask(
                                    Task(
                                      id: task.id,
                                      projectId: task.projectId,
                                      title: task.title,
                                      isCompleted: value ?? false,
                                    ),
                                  );
                                },
                              ),
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isCompleted ? Colors.grey : null,
                                ),
                              ),
                              subtitle:
                                  Text(project?.name ?? 'Unknown Project'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showTaskDialog(context,
                                        existingTask: task);
                                  } else if (value == 'delete') {
                                    _confirmDelete(context, task);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
