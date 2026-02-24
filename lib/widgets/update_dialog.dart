import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api/app_version_service.dart';

/// Dialog informujący o dostępnej aktualizacji
class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismiss;
  final VoidCallback? onUpdate;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onDismiss,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForceUpdate = updateInfo.needsForceUpdate;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isForceUpdate ? Icons.warning_amber_rounded : Icons.system_update,
            color: isForceUpdate ? Colors.orange : theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isForceUpdate ? 'Wymagana aktualizacja' : 'Dostępna aktualizacja',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVersionRow(
            'Twoja wersja:',
            updateInfo.currentVersion,
            theme,
          ),
          const SizedBox(height: 8),
          _buildVersionRow(
            'Nowa wersja:',
            updateInfo.latestVersion,
            theme,
            isNew: true,
          ),
          if (updateInfo.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Co nowego:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(
                  updateInfo.releaseNotes,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          if (isForceUpdate) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ta aktualizacja jest wymagana do dalszego korzystania z aplikacji.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!isForceUpdate)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: const Text('Później'),
          ),
        FilledButton.icon(
          onPressed: () {
            _handleUpdate(context);
          },
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Aktualizuj'),
        ),
      ],
    );
  }

  Widget _buildVersionRow(String label, String version, ThemeData theme, {bool isNew = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isNew 
                ? theme.colorScheme.primary.withOpacity(0.1) 
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: isNew 
                ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3))
                : null,
          ),
          child: Text(
            'v$version',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isNew ? theme.colorScheme.primary : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpdate(BuildContext context) async {
    final url = updateInfo.downloadUrl;
    
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nie można otworzyć linku do pobrania'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link do aktualizacji niedostępny dla tej platformy'),
          ),
        );
      }
    }
    
    onUpdate?.call();
  }

  /// Wyświetla dialog aktualizacji
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo, {
    VoidCallback? onDismiss,
    VoidCallback? onUpdate,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.needsForceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo.needsForceUpdate,
        child: UpdateDialog(
          updateInfo: updateInfo,
          onDismiss: onDismiss,
          onUpdate: onUpdate,
        ),
      ),
    );
  }
}

/// Przycisk do ręcznego sprawdzania aktualizacji (np. w ustawieniach)
class CheckUpdateButton extends StatefulWidget {
  final Future<AppUpdateInfo?> Function() onCheckUpdate;

  const CheckUpdateButton({
    super.key,
    required this.onCheckUpdate,
  });

  @override
  State<CheckUpdateButton> createState() => _CheckUpdateButtonState();
}

class _CheckUpdateButtonState extends State<CheckUpdateButton> {
  bool _isChecking = false;

  Future<void> _checkForUpdate() async {
    setState(() => _isChecking = true);
    
    try {
      final updateInfo = await widget.onCheckUpdate();
      
      if (!mounted) return;
      
      if (updateInfo != null && updateInfo.needsUpdate) {
        await UpdateDialog.show(context, updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masz najnowszą wersję aplikacji!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd sprawdzania: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update),
      title: const Text('Sprawdź aktualizacje'),
      subtitle: Text('Wersja: ${AppVersionService.currentVersion}'),
      trailing: _isChecking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _isChecking ? null : _checkForUpdate,
    );
  }
}
