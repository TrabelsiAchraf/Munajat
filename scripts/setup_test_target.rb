#!/usr/bin/env ruby
# frozen_string_literal: true
#
# setup_test_target.rb
# Idempotent setup of the AdhkarTests unit-test bundle target.
# Run from repo root: `ruby scripts/setup_test_target.rb`.
#
# Deployment targets are derived from the host Adhkar target's Debug config so
# they always stay in sync — mirrors the pattern in setup_widget_target.rb.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Adhkar.xcodeproj', __dir__)
MAIN_TARGET  = 'Adhkar'
TARGET_NAME  = 'AdhkarTests'

project  = Xcodeproj::Project.open(PROJECT_PATH)
host_app = project.targets.find { |t| t.name == MAIN_TARGET } \
  or abort("#{MAIN_TARGET} target not found")

# Derive deployment targets from the host's Debug build config.
host_debug   = host_app.build_configurations.find { |c| c.name == 'Debug' }.build_settings
ios_target   = host_debug['IPHONEOS_DEPLOYMENT_TARGET']
macos_target = host_debug['MACOSX_DEPLOYMENT_TARGET']
xros_target  = host_debug['XROS_DEPLOYMENT_TARGET']

# --- 1. Find or create the test target ---
test_target = project.targets.find { |t| t.name == TARGET_NAME }
if test_target
  puts "Target #{TARGET_NAME} already exists — updating settings."
else
  tests_group = project.main_group.find_subpath(TARGET_NAME, true)
  tests_group.set_source_tree('SOURCE_ROOT')
  tests_group.set_path(TARGET_NAME)

  test_target = project.new_target(:unit_test_bundle, TARGET_NAME, :ios, ios_target, nil, :swift)
  test_target.add_dependency(host_app)

  placeholder = tests_group.new_file('PlaceholderTest.swift')
  test_target.add_file_references([placeholder])
end

# --- 2. Build settings (applied idempotently to every config) ---
test_target.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE']    = 'YES'
  config.build_settings['PRODUCT_NAME']               = '$(TARGET_NAME)'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']  = 'com.tadevv.munajat.tests'
  config.build_settings['SWIFT_VERSION']              = '6.0'
  config.build_settings['TEST_HOST']                  = '$(BUILT_PRODUCTS_DIR)/Adhkar.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Adhkar'
  config.build_settings['BUNDLE_LOADER']              = '$(TEST_HOST)'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_target
  config.build_settings['MACOSX_DEPLOYMENT_TARGET']   = macos_target
  config.build_settings['XROS_DEPLOYMENT_TARGET']     = xros_target
  config.build_settings['SUPPORTED_PLATFORMS']        = 'iphoneos iphonesimulator macosx xros xrsimulator'
end

# --- 3. Wire into the Adhkar scheme's Test action (idempotent) ---
scheme_path = File.join(PROJECT_PATH, 'xcshareddata/xcschemes/Adhkar.xcscheme')
scheme      = Xcodeproj::XCScheme.new(scheme_path)
test_action = scheme.test_action
existing_ids = test_action.testables.map { |t| t.buildable_references.first.target_uuid rescue nil }
unless existing_ids.include?(test_target.uuid)
  testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
  test_action.add_testable(testable)
  scheme.save!
end

project.save
puts "✓ #{TARGET_NAME} target configured (bundle ID: com.tadevv.munajat.tests, iOS #{ios_target} / macOS #{macos_target} / xrOS #{xros_target})."
