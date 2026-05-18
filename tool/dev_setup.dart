import 'dart:io';

/// Developer setup script for Fun Sheet Music.
/// Run this once after cloning the repository to configure your local environment.
void main() async {
  print('🎵 Fun Sheet Music - Developer Setup\n');

  var allSuccessful = true;

  // Step 1: Configure Git merge strategy for auto-generated files
  print('📝 Configuring Git merge strategy for auto-generated files...');
  final gitConfigDriver = await Process.run(
    'git',
    ['config', 'merge.theirs.driver', 'cp -f %B %A'],
  );
  final gitConfigName = await Process.run(
    'git',
    ['config', 'merge.theirs.name', 'Always use remote version'],
  );

  if (gitConfigDriver.exitCode == 0 && gitConfigName.exitCode == 0) {
    print('   ✅ Git merge driver configured');
    print('   → Auto-generated files will use remote version during conflicts\n');
  } else {
    print('   ❌ Failed to configure Git merge driver');
    print('   ${gitConfigDriver.stderr}${gitConfigName.stderr}\n');
    allSuccessful = false;
  }

  // Step 2: Install Flutter dependencies
  print('📦 Installing Flutter dependencies...');
  final pubGet = await Process.run('flutter', ['pub', 'get']);
  
  if (pubGet.exitCode == 0) {
    print('   ✅ Dependencies installed\n');
  } else {
    print('   ❌ Failed to install dependencies');
    print('   ${pubGet.stderr}\n');
    allSuccessful = false;
  }

  // Step 3: Verify Flutter installation
  print('🔍 Verifying Flutter environment...');
  final flutterDoctor = await Process.run(
    'flutter',
    ['doctor', '--no-version-check'],
  );
  
  if (flutterDoctor.exitCode == 0) {
    print('   ✅ Flutter environment ready\n');
  } else {
    print('   ⚠️  Some Flutter checks failed');
    print('   Run `flutter doctor` to see details\n');
  }

  // Summary
  print('━' * 60);
  if (allSuccessful) {
    print('✨ Setup complete! You\'re ready to start developing.\n');
    print('Quick start:');
    print('  • flutter run            - Run on default device');
    print('  • flutter run -d chrome  - Run on web');
    print('  • flutter test           - Run tests');
    print('\nDevelopment tools:');
    print('  • dart run tool/generate_icons.dart          - Generate app icons');
    print('  • dart run tool/generate_community_manifest.dart - Update song manifest');
    print('  • dart run tool/sync_metadata.dart           - Sync metadata');
  } else {
    print('⚠️  Setup completed with some errors. Please review above.\n');
  }
  print('━' * 60);
}
