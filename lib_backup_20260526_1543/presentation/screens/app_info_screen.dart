import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/environment.dart';
import '../../core/layout/app_layout.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/async_state_view.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  String get _environmentLabel {
    return switch (currentEnv) {
      Environment.dev => 'development',
      Environment.prod => 'production',
    };
  }

  String get _buildModeLabel {
    if (kReleaseMode) {
      return 'release';
    }
    if (kProfileMode) {
      return 'profile';
    }
    return 'debug';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: const Text('App Info & Diagnostics')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingView(label: 'Loading app details');
          }

          final info = snapshot.data;

          return ListView(
            padding: EdgeInsets.all(context.pageHorizontalPadding),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.apps_outlined),
                  title: const Text('Application'),
                  subtitle: Text(info?.appName ?? 'MixVy'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.tag_outlined),
                      title: const Text('Version'),
                      subtitle: Text(info?.version ?? 'Unknown'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.confirmation_num_outlined),
                      title: const Text('Build Number'),
                      subtitle: Text(info?.buildNumber ?? 'Unknown'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.memory_outlined),
                      title: const Text('Build Mode'),
                      subtitle: Text(_buildModeLabel),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.rocket_launch_outlined),
                      title: const Text('Environment'),
                      subtitle: Text(_environmentLabel),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.web_outlined),
                      title: const Text('Platform'),
                      subtitle: Text(defaultTargetPlatform.name),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Use this panel when reporting bugs or requesting support so build and environment details are included.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
