import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/app_layout.dart';
import '../providers/groups_provider.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_page_scaffold.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  final String userId;

  const CreateGroupScreen({super.key, required this.userId});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(groupsControllerProvider).createGroup(
            userId: widget.userId,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group created!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      appBar: AppBar(
        backgroundColor: VelvetNoir.surface,
        title: const Text(
          'Create Group',
          style: TextStyle(
            color: VelvetNoir.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: VelvetNoir.onSurface),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: const TextStyle(color: VelvetNoir.onSurfaceVariant),
                hintText: 'Enter a name for your group',
                hintStyle: const TextStyle(color: VelvetNoir.onSurfaceVariant),
                filled: true,
                fillColor: VelvetNoir.surfaceContainer,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: VelvetNoir.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: VelvetNoir.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Description field
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: VelvetNoir.onSurface),
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: VelvetNoir.onSurfaceVariant),
                hintText: 'What is this group about?',
                hintStyle: const TextStyle(color: VelvetNoir.onSurfaceVariant),
                filled: true,
                fillColor: VelvetNoir.surfaceContainer,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: VelvetNoir.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: VelvetNoir.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Create button
            ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetNoir.primaryDim,
                foregroundColor: VelvetNoir.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: VelvetNoir.surfaceBright,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VelvetNoir.primary,
                      ),
                    )
                  : const Text(
                      'Create Group',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
