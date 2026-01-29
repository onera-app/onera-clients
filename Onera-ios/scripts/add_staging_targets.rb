#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to add staging targets for macOS and watchOS
# Run: ruby scripts/add_staging_targets.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Onera.xcodeproj', __dir__)
DEVELOPMENT_TEAM = 'FYS9RNAGTV' # Same as iOS staging

def main
  puts "Opening project: #{PROJECT_PATH}"
  project = Xcodeproj::Project.open(PROJECT_PATH)
  
  # Add macOS Staging target
  add_macos_staging_target(project)
  
  # Add watchOS Staging target  
  add_watchos_staging_target(project)
  
  # Update existing targets to use Production config
  update_existing_targets_for_production(project)
  
  # Add schemes
  add_schemes(project)
  
  project.save
  puts "\nProject saved successfully!"
  puts "\nNext steps:"
  puts "1. Open Xcode and verify the new targets"
  puts "2. In Xcode, drag Onera-macOS folder to 'Onera-macOS Staging' target's Build Phases > Compile Sources"
  puts "3. Set signing team for new targets"
  puts "4. Add package dependencies to new targets"
end

def add_macos_staging_target(project)
  puts "\n--- Adding Onera-macOS Staging target ---"
  
  # Find existing macOS target
  macos_target = project.targets.find { |t| t.name == 'Onera-macOS' }
  unless macos_target
    puts "ERROR: Could not find Onera-macOS target"
    return
  end
  
  # Check if staging target already exists
  if project.targets.find { |t| t.name == 'Onera-macOS Staging' }
    puts "Onera-macOS Staging target already exists, skipping..."
    return
  end
  
  # Create new native target
  staging_target = project.new_target(
    :application,
    'Onera-macOS Staging',
    :osx,
    '14.0'
  )
  
  # Configure build settings for Debug
  debug_config = staging_target.build_configurations.find { |c| c.name == 'Debug' }
  configure_macos_staging_settings(debug_config)
  
  # Configure build settings for Release
  release_config = staging_target.build_configurations.find { |c| c.name == 'Release' }
  configure_macos_staging_settings(release_config)
  
  puts "Created Onera-macOS Staging target"
  puts "NOTE: You need to manually add the Onera-macOS folder to this target's file system synchronized groups in Xcode"
end

def configure_macos_staging_settings(config)
  config.build_settings['PRODUCT_NAME'] = 'Onera-macOS Staging'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'staging.app.onera.macos'
  config.build_settings['INFOPLIST_FILE'] = 'Onera-macOS/Info-Staging.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Onera-macOS/Onera-macOS-Staging.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = DEVELOPMENT_TEAM
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SDKROOT'] = 'macosx'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['COMBINE_HIDPI_IMAGES'] = 'YES'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  config.build_settings['ENABLE_APP_SANDBOX'] = 'YES'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  config.build_settings['SWIFT_APPROACHABLE_CONCURRENCY'] = 'YES'
  config.build_settings['SWIFT_DEFAULT_ACTOR_ISOLATION'] = 'MainActor'
  config.build_settings['SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY'] = 'YES'
end

def add_watchos_staging_target(project)
  puts "\n--- Adding Onera-watchOS Staging target ---"
  
  # Find existing watchOS target
  watchos_target = project.targets.find { |t| t.name == 'Onera-watchOS' }
  unless watchos_target
    puts "ERROR: Could not find Onera-watchOS target"
    return
  end
  
  # Check if staging target already exists
  if project.targets.find { |t| t.name == 'Onera-watchOS Staging' }
    puts "Onera-watchOS Staging target already exists, skipping..."
    return
  end
  
  # Create new watch app target
  staging_target = project.new_target(
    :watch2_app,
    'Onera-watchOS Staging',
    :watchos,
    '10.0'
  )
  
  # Configure build settings for Debug
  debug_config = staging_target.build_configurations.find { |c| c.name == 'Debug' }
  configure_watchos_staging_settings(debug_config)
  
  # Configure build settings for Release
  release_config = staging_target.build_configurations.find { |c| c.name == 'Release' }
  configure_watchos_staging_settings(release_config)
  release_config.build_settings['VALIDATE_PRODUCT'] = 'YES'
  
  # Add dependency to iOS Staging target and embed watch content
  add_watchos_to_ios_staging(project, staging_target)
  
  puts "Created Onera-watchOS Staging target"
  puts "NOTE: You need to manually add the source files to this target in Xcode"
end

def configure_watchos_staging_settings(config)
  config.build_settings['PRODUCT_NAME'] = 'Onera-watchOS Staging'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'staging.app.onera.watchkitapp'
  config.build_settings['INFOPLIST_FILE'] = 'Onera-watchOS/Info-Staging.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Onera-watchOS/Onera-watchOS-Staging.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = DEVELOPMENT_TEAM
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['WK_COMPANION_APP_BUNDLE_IDENTIFIER'] = 'staging.app.onera'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

def add_watchos_to_ios_staging(project, watch_staging_target)
  ios_staging = project.targets.find { |t| t.name == 'Onera Staging' }
  return unless ios_staging
  
  # Add watch app as dependency
  ios_staging.add_dependency(watch_staging_target)
  
  # Find or create embed watch content build phase
  embed_phase = ios_staging.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Embed Watch Content' }
  
  unless embed_phase
    embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed_phase.name = 'Embed Watch Content'
    embed_phase.dst_subfolder_spec = '16' # Watch folder
    embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
    ios_staging.build_phases << embed_phase
  end
  
  # Add the staging watch app to embed phase
  if watch_staging_target.product_reference
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.file_ref = watch_staging_target.product_reference
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
    embed_phase.files << build_file
  end
  
  puts "Added watchOS Staging dependency to iOS Staging"
end

def update_existing_targets_for_production(project)
  puts "\n--- Updating existing targets for Production ---"
  
  # Update macOS target
  macos_target = project.targets.find { |t| t.name == 'Onera-macOS' }
  if macos_target
    macos_target.build_configurations.each do |config|
      config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'prod.app.onera.macos'
      config.build_settings['DEVELOPMENT_TEAM'] = DEVELOPMENT_TEAM
    end
    puts "Updated Onera-macOS for production"
  end
  
  # Update watchOS target
  watchos_target = project.targets.find { |t| t.name == 'Onera-watchOS' }
  if watchos_target
    watchos_target.build_configurations.each do |config|
      config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'prod.app.onera.watchkitapp'
      config.build_settings['WK_COMPANION_APP_BUNDLE_IDENTIFIER'] = 'prod.app.onera'
      config.build_settings['DEVELOPMENT_TEAM'] = DEVELOPMENT_TEAM
    end
    puts "Updated Onera-watchOS for production"
  end
end

def add_schemes(project)
  puts "\n--- Adding schemes ---"
  
  schemes_dir = File.join(PROJECT_PATH, 'xcshareddata', 'xcschemes')
  FileUtils.mkdir_p(schemes_dir)
  
  # Create macOS Staging scheme
  create_scheme(schemes_dir, 'Onera-macOS Staging', 'Onera-macOS Staging')
  
  # Create watchOS Staging scheme  
  create_scheme(schemes_dir, 'Onera-watchOS Staging', 'Onera-watchOS Staging')
  
  puts "Created schemes"
end

def create_scheme(schemes_dir, scheme_name, target_name)
  scheme_path = File.join(schemes_dir, "#{scheme_name}.xcscheme")
  
  # Skip if already exists
  return if File.exist?(scheme_path)
  
  scheme_content = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Scheme
       LastUpgradeVersion = "1520"
       version = "1.3">
       <BuildAction
          parallelizeBuildables = "YES"
          buildImplicitDependencies = "YES">
          <BuildActionEntries>
             <BuildActionEntry
                buildForTesting = "YES"
                buildForRunning = "YES"
                buildForProfiling = "YES"
                buildForArchiving = "YES"
                buildForAnalyzing = "YES">
                <BuildableReference
                   BuildableIdentifier = "primary"
                   BlueprintIdentifier = ""
                   BuildableName = "#{target_name}.app"
                   BlueprintName = "#{target_name}"
                   ReferencedContainer = "container:Onera.xcodeproj">
                </BuildableReference>
             </BuildActionEntry>
          </BuildActionEntries>
       </BuildAction>
       <TestAction
          buildConfiguration = "Debug"
          selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
          selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
          shouldUseLaunchSchemeArgsEnv = "YES">
       </TestAction>
       <LaunchAction
          buildConfiguration = "Debug"
          selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
          selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
          launchStyle = "0"
          useCustomWorkingDirectory = "NO"
          ignoresPersistentStateOnLaunch = "NO"
          debugDocumentVersioning = "YES"
          debugServiceExtension = "internal"
          allowLocationSimulation = "YES">
          <BuildableProductRunnable
             runnableDebuggingMode = "0">
             <BuildableReference
                BuildableIdentifier = "primary"
                BlueprintIdentifier = ""
                BuildableName = "#{target_name}.app"
                BlueprintName = "#{target_name}"
                ReferencedContainer = "container:Onera.xcodeproj">
             </BuildableReference>
          </BuildableProductRunnable>
       </LaunchAction>
       <ProfileAction
          buildConfiguration = "Release"
          shouldUseLaunchSchemeArgsEnv = "YES"
          savedToolIdentifier = ""
          useCustomWorkingDirectory = "NO"
          debugDocumentVersioning = "YES">
          <BuildableProductRunnable
             runnableDebuggingMode = "0">
             <BuildableReference
                BuildableIdentifier = "primary"
                BlueprintIdentifier = ""
                BuildableName = "#{target_name}.app"
                BlueprintName = "#{target_name}"
                ReferencedContainer = "container:Onera.xcodeproj">
             </BuildableReference>
          </BuildableProductRunnable>
       </ProfileAction>
       <AnalyzeAction
          buildConfiguration = "Debug">
       </AnalyzeAction>
       <ArchiveAction
          buildConfiguration = "Release"
          revealArchiveInOrganizer = "YES">
       </ArchiveAction>
    </Scheme>
  XML
  
  File.write(scheme_path, scheme_content)
end

# Run the script
main
