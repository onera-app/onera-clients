#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Onera.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.find { |t| t.name == 'OneraUITests' }
  puts "OneraUITests target already exists"
  exit 0
end

# Find main app target
main_target = project.targets.find { |t| t.name == 'Onera' }
unless main_target
  puts "Could not find Onera target"
  exit 1
end

# Create UI test target
ui_test_target = project.new_target(
  :ui_test_bundle,
  'OneraUITests',
  :ios,
  '17.0'
)

# Add test files group
ui_tests_group = project.main_group.new_group('OneraUITests', 'OneraUITests')

# Add source files
Dir.glob('OneraUITests/*.swift').each do |file|
  file_ref = ui_tests_group.new_file(file)
  ui_test_target.add_file_references([file_ref])
end

# Set target dependency
ui_test_target.add_dependency(main_target)

# Configure build settings
ui_test_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = ''
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'chat.onera.staging.uitests'
  config.build_settings['TEST_TARGET_NAME'] = 'Onera'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator macosx'
  config.build_settings['SUPPORTS_MACCATALYST'] = 'YES'
  config.build_settings['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
end

# Save project
project.save

puts "Successfully added OneraUITests target"
