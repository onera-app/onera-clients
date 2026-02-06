#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Onera.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find UI test target
ui_test_target = project.targets.find { |t| t.name == 'OneraUITests' }
unless ui_test_target
  puts "OneraUITests target not found"
  exit 1
end

# Fix build settings
ui_test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'chat.onera.staging.uitests'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Onera.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Onera'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['TEST_TARGET_NAME'] = 'Onera'
  config.build_settings['INFOPLIST_FILE'] = ''
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator macosx'
  config.build_settings['SUPPORTS_MACCATALYST'] = 'YES'
  config.build_settings['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
  
  # UI test specific - remove TEST_HOST for UI tests (they launch the app externally)
  config.build_settings.delete('TEST_HOST')
  config.build_settings.delete('BUNDLE_LOADER')
end

# Save project
project.save

puts "Successfully fixed OneraUITests target"
