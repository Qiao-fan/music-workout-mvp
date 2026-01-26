import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class AssignScreen extends ConsumerStatefulWidget {
  const AssignScreen({super.key});

  @override
  ConsumerState<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends ConsumerState<AssignScreen> {
  final _searchController = TextEditingController();
  String? _selectedPlanId;
  AppUser? _selectedStudent;
  List<AppUser> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final results = await firebaseService.searchStudents(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _selectStudent(AppUser student) {
    setState(() {
      _selectedStudent = student;
      _searchController.text = '${student.displayName} (${student.email})';
      _searchResults = [];
    });
  }

  Future<void> _assignPlan() async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plan')),
      );
      return;
    }

    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a student')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final teacherId = firebaseService.currentUser?.uid;

      if (teacherId == null) throw Exception('Not logged in');

      // Create assignment
      final assignment = Assignment(
        id: '',
        teacherId: teacherId,
        studentId: _selectedStudent!.id,
        studentEmail: _selectedStudent!.email,
        planId: _selectedPlanId!,
        assignedAt: DateTime.now(),
      );

      await firebaseService.createAssignment(assignment);

      if (mounted) {
        _searchController.clear();
        setState(() {
          _selectedPlanId = null;
          _selectedStudent = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Plan assigned successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final teacherId = currentUser.valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Plan'),
      ),
      body: teacherId == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(teacherId),
    );
  }

  Widget _buildBody(String teacherId) {
    final plansAsync = ref.watch(teacherPlansProvider(teacherId));
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider(teacherId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'New Assignment',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Student search field
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Student',
                      hintText: 'Type name or email to search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _selectedStudent != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _selectedStudent = null;
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      if (_selectedStudent == null) {
                        _searchStudents(value);
                      }
                    },
                    onTap: () {
                      if (_selectedStudent != null) {
                        _searchController.clear();
                        setState(() {
                          _selectedStudent = null;
                          _searchResults = [];
                        });
                      }
                    },
                  ),
                  
                  // Search results
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final student = _searchResults[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(student.displayName),
                            subtitle: Text(student.email),
                            onTap: () => _selectStudent(student),
                          );
                        },
                      ),
                    )
                  else if (_searchController.text.isNotEmpty && _selectedStudent == null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No students found. Make sure they have signed up as a student.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  
                  if (_selectedStudent != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${_selectedStudent!.displayName}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  plansAsync.when(
                    data: (plans) {
                      final publishedPlans =
                          plans.where((p) => p.published).toList();
                      if (publishedPlans.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'No published plans. Create and publish a plan first.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedPlanId,
                        decoration: const InputDecoration(
                          labelText: 'Select Plan',
                          prefixIcon: Icon(Icons.library_music),
                        ),
                        items: publishedPlans
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.title),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedPlanId = value),
                        hint: const Text('Choose a plan'),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Error: $error'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _assignPlan,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Assign Plan'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Assignments',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          assignmentsAsync.when(
            data: (assignments) {
              if (assignments.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No assignments yet',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  return _AssignmentCard(
                    assignment: assignment,
                    onViewProgress: () => context.push(
                      '/teacher/student/${assignment.studentId}/progress',
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends ConsumerWidget {
  final Assignment assignment;
  final VoidCallback onViewProgress;

  const _AssignmentCard({
    required this.assignment,
    required this.onViewProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planProvider(assignment.planId));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(assignment.studentEmail),
        subtitle: planAsync.when(
          data: (plan) => Text(plan?.title ?? 'Unknown Plan'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        trailing: TextButton(
          onPressed: onViewProgress,
          child: const Text('Progress'),
        ),
      ),
    );
  }
}
