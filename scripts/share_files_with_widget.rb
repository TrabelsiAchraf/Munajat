#!/usr/bin/env ruby
# frozen_string_literal: true
#
# share_files_with_widget.rb
# Attach a curated subset of files from the Adhkar/ synchronized root group
# to the MunajatWidget target via a PBXFileSystemSynchronizedBuildFileExceptionSet.
# Idempotent.

require 'xcodeproj'

# Paths are relative to the Adhkar/ synchronized root group root.
SHARED_FILES = %w[
  Models/AdhkarCategory.swift
  Models/AdhkarType.swift
  Models/AdhkarSection+Display.swift
  Models/LocalizedText.swift
  Services/DataProvider.swift
  Localization/L10n.swift
  Design/CrescentStarPattern.swift
  Design/Color+Extension.swift
  Design/Font+Arabic.swift
  Design/IslamicPattern.swift
  Resources/adhkar.json
  Resources/Amiri-Regular.ttf
  Resources/Amiri-Bold.ttf
  Resources/AmiriQuran.ttf
].freeze

project = Xcodeproj::Project.open('Adhkar.xcodeproj')
widget = project.targets.find { |t| t.name == 'MunajatWidget' } \
  or abort('MunajatWidget target not found — run setup_widget_target.rb first')

adhkar_group = project.main_group.children.find do |child|
  child.is_a?(Xcodeproj::Project::PBXFileSystemSynchronizedRootGroup) && child.path == 'Adhkar'
end
abort('Adhkar synchronized root group not found') unless adhkar_group

# Look for an existing exception set already pointing at MunajatWidget.
existing = (adhkar_group.exceptions || []).find do |ex|
  ex.is_a?(Xcodeproj::Project::PBXFileSystemSynchronizedBuildFileExceptionSet) && ex.target == widget
end

if existing
  existing.membership_exceptions = SHARED_FILES
  puts "✓ Updated existing exception set with #{SHARED_FILES.size} files."
else
  ex_set = project.new(Xcodeproj::Project::PBXFileSystemSynchronizedBuildFileExceptionSet)
  ex_set.target = widget
  ex_set.membership_exceptions = SHARED_FILES
  adhkar_group.exceptions ||= []
  adhkar_group.exceptions << ex_set
  puts "✓ Created exception set sharing #{SHARED_FILES.size} files with MunajatWidget."
end

project.save
