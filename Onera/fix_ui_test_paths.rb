#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Onera.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the OneraUITests group
ui_tests_group = project.main_group.groups.find { |g| g.name == 'OneraUITests' }

if ui_tests_group
  # Fix file references - remove the extra directory level
  ui_tests_group.files.each do |file_ref|
    if file_ref.path && file_ref.path.include?('OneraUITests/')
      # Remove the extra 'OneraUITests/' prefix
      new_path = file_ref.path.gsub('OneraUITests/', '')
      file_ref.path = new_path
      puts "Fixed path: #{new_path}"
    end
  end
  
  # Set the group path correctly
  ui_tests_group.path = 'OneraUITests'
  ui_tests_group.source_tree = '<group>'
end

# Save project
project.save

puts "Successfully fixed file paths"
