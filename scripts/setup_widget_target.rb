#!/usr/bin/env ruby
# frozen_string_literal: true
#
# setup_widget_target.rb
# One-shot, idempotent setup of the MunajatWidget Widget Extension target.
# Run from repo root: `ruby scripts/setup_widget_target.rb`.
#
# Performed steps:
#   1. Create the PBXNativeTarget (app_extension, iOS-only).
#   2. Wire build settings (bundle id, entitlements, INFOPLIST_FILE,
#      SUPPORTED_PLATFORMS=iphoneos iphonesimulator, MARKETING_VERSION, …).
#   3. Add a PBXFileSystemSynchronizedRootGroup for MunajatWidget/ scoped
#      to the widget target (so the .swift files auto-bundle).
#   4. Add an "Embed Foundation Extensions" copy phase to the main Adhkar
#      target referencing the widget, scoped to iOS via platform filter
#      so macOS/visionOS builds skip the iOS-only widget.
#   5. Mark the widget as a dependency of the main target.
#   6. Switch the main app to merge Adhkar-SupportingFiles/Adhkar-URLTypes.plist
#      with the auto-generated Info.plist (Xcode 14+ INFOPLIST_FILE merge)
#      so `munajat://` is registered.

require 'xcodeproj'

PROJECT_PATH = 'Adhkar.xcodeproj'
MAIN_TARGET  = 'Adhkar'
WIDGET_NAME  = 'MunajatWidget'
TEAM_ID      = 'D44ZSJA8CM'

project = Xcodeproj::Project.open(PROJECT_PATH)
main = project.targets.find { |t| t.name == MAIN_TARGET } \
  or abort("Main target #{MAIN_TARGET} not found")
main_settings = main.build_configurations.find { |c| c.name == 'Debug' }.build_settings
ios_deployment = main_settings['IPHONEOS_DEPLOYMENT_TARGET']

# --- 1. Widget target ---
widget = project.targets.find { |t| t.name == WIDGET_NAME }
if widget
  puts "✓ Target #{WIDGET_NAME} already exists, skipping creation."
else
  widget = project.new_target(:app_extension, WIDGET_NAME, :ios, ios_deployment, nil, :swift)
end

# --- 2. Build settings ---
widget_settings = {
  'PRODUCT_BUNDLE_IDENTIFIER'         => "com.tadevv.Adhkar.#{WIDGET_NAME}",
  'PRODUCT_NAME'                      => '$(TARGET_NAME)',
  'CODE_SIGN_ENTITLEMENTS'            => "#{WIDGET_NAME}-SupportingFiles/#{WIDGET_NAME}.entitlements",
  'CODE_SIGN_STYLE'                   => 'Automatic',
  'DEVELOPMENT_TEAM'                  => TEAM_ID,
  'CURRENT_PROJECT_VERSION'           => '1',
  'MARKETING_VERSION'                 => '1.0',
  'SWIFT_VERSION'                     => '5.0',
  'SWIFT_EMIT_LOC_STRINGS'            => 'YES',
  'GENERATE_INFOPLIST_FILE'           => 'NO',
  'INFOPLIST_FILE'                    => "#{WIDGET_NAME}-SupportingFiles/Info.plist",
  'IPHONEOS_DEPLOYMENT_TARGET'        => ios_deployment,
  'SDKROOT'                           => 'iphoneos',
  'SUPPORTED_PLATFORMS'               => 'iphoneos iphonesimulator',
  'TARGETED_DEVICE_FAMILY'            => '1,2',
  'SKIP_INSTALL'                      => 'YES',
  'ENABLE_PREVIEWS'                   => 'YES',
  'LD_RUNPATH_SEARCH_PATHS'           => '@executable_path/Frameworks @executable_path/../../Frameworks',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Munajat',
}
widget.build_configurations.each { |c| c.build_settings.merge!(widget_settings) }

# --- 3. Synchronized root group ---
sync_group = project.main_group.children.find do |child|
  child.is_a?(Xcodeproj::Project::PBXFileSystemSynchronizedRootGroup) && child.path == WIDGET_NAME
end
unless sync_group
  sync_group = project.new(Xcodeproj::Project::PBXFileSystemSynchronizedRootGroup)
  sync_group.path = WIDGET_NAME
  sync_group.source_tree = '<group>'
  project.main_group.children << sync_group
end
widget.file_system_synchronized_groups ||= []
widget.file_system_synchronized_groups << sync_group unless widget.file_system_synchronized_groups.include?(sync_group)

# --- 4. Embed phase (iOS-only platform filter) ---
embed = main.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed
  embed = project.new(Xcodeproj::Project::PBXCopyFilesBuildPhase)
  embed.name = 'Embed Foundation Extensions'
  embed.symbol_dst_subfolder_spec = :plug_ins
  main.build_phases << embed
end
unless embed.files.any? { |f| f.display_name == "#{WIDGET_NAME}.appex" }
  build_file = embed.add_file_reference(widget.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end
embed.files.select { |f| f.display_name == "#{WIDGET_NAME}.appex" }
     .each { |f| f.platform_filters = %w[ios] }

# --- 5. Dependency ---
unless main.dependencies.any? { |d| d.target == widget }
  main.add_dependency(widget)
end

# --- 6. URL scheme via Info.plist merge ---
main.build_configurations.each do |c|
  c.build_settings['INFOPLIST_FILE'] = 'Adhkar-SupportingFiles/Adhkar-URLTypes.plist'
end

project.save
puts "✓ MunajatWidget target wired (embed iOS-only) + munajat:// scheme registered."
