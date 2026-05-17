#!/usr/bin/env ruby
# Adds an `AdhkarTests` Swift Testing unit-test bundle target to Adhkar.xcodeproj.
# Idempotent — re-running is a no-op once the target exists.

require 'xcodeproj'

project_path = File.expand_path('../Adhkar.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

target_name = 'AdhkarTests'
host_app    = project.targets.find { |t| t.name == 'Adhkar' } or abort 'Adhkar target not found'

if project.targets.any? { |t| t.name == target_name }
  puts "Target #{target_name} already exists — nothing to do."
  exit 0
end

tests_group = project.main_group.find_subpath('AdhkarTests', true)
tests_group.set_source_tree('SOURCE_ROOT')
tests_group.set_path('AdhkarTests')

test_target = project.new_target(:unit_test_bundle, target_name, :ios, '17.0', nil, :swift)
test_target.add_dependency(host_app)

test_target.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.tadev.munajat.tests'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['TEST_HOST'] = "$(BUILT_PRODUCTS_DIR)/Adhkar.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Adhkar"
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['XROS_DEPLOYMENT_TARGET'] = '1.0'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator macosx xros xrsimulator'
end

placeholder = tests_group.new_file('PlaceholderTest.swift')
test_target.add_file_references([placeholder])

scheme_path = File.join(project_path, 'xcshareddata/xcschemes/Adhkar.xcscheme')
scheme = Xcodeproj::XCScheme.new(scheme_path)
test_action = scheme.test_action
existing_ids = test_action.testables.map { |t| t.buildable_references.first.target_uuid rescue nil }
unless existing_ids.include?(test_target.uuid)
  testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
  test_action.add_testable(testable)
  scheme.save!
end

project.save
puts "Created #{target_name} target."
