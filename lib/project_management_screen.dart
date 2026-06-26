import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'time_entry_provider.dart';

class ProjectManagementScreen extends StatelessWidget {
  const ProjectManagementScreen({super.key});

  void _showProjectDialog(BuildContext context, {Project? existingProject}) {
    final nameController =
        TextEditingController(text: existingProject?.name ?? '');
    final descriptionController =
        TextEditingController(text: existingProject?.description ?? '');
    final formKey = GlobalKey<FormState>();
    final isEditing = existingProject != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Project' : 'New Project'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Project Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                  maxLines: 2,
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

                final provider = Provider.of<TimeEntryProvider>(
                  context,
                  listen: false,
                );

                if (isEditing) {
                  provider.updateProject(
                    Project(
                      id: existingProject.id,
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                    ),
                  );
                } else {
                  provider.addProject(
                    Project(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
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
  }

  void _confirmDelete(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Project?'),
          content: Text(
            'This will permanently delete "${project.name}" along with '
            'all its tasks and time entries. This cannot be undone.',
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
                    .deleteProject(project.id);
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
      appBar: AppBar(title: const Text('Manage Projects')),
      body: Consumer<TimeEntryProvider>(
        builder: (context, provider, child) {
          final projects = provider.projects;

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (projects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_off_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No projects yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the button below to create your first project.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final taskCount = provider.getTasksForProject(project.id).length;
              final totalMinutes = provider.totalMinutesForProject(project.id);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    project.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    project.description.isNotEmpty
                        ? '${project.description}\n$taskCount tasks • '
                            '${(totalMinutes / 60).toStringAsFixed(1)}h logged'
                        : '$taskCount tasks • '
                            '${(totalMinutes / 60).toStringAsFixed(1)}h logged',
                  ),
                  isThreeLine: project.description.isNotEmpty,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showProjectDialog(context, existingProject: project);
                      } else if (value == 'delete') {
                        _confirmDelete(context, project);
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
