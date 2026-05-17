#!/usr/bin/env ruby
# frozen_string_literal: true
#
# sync_test_sources.rb
# Idempotent: adds any AdhkarTests/*.swift files missing from the target's
# Sources build phase, and removes references to files that no longer exist on disk.
# Run from repo root: `ruby scripts/sync_test_sources.rb`

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Adhkar.xcodeproj', __dir__)
TARGET_NAME  = 'AdhkarTests'
TESTS_DIR    = File.expand_path('../AdhkarTests', __dir__)

project     = Xcodeproj::Project.open(PROJECT_PATH)
test_target = project.targets.find { |t| t.name == TARGET_NAME } \
  or abort("#{TARGET_NAME} target not found")

# The Xcode group for AdhkarTests (path-based, not synchronized)
tests_group = project.main_group.find_subpath(TARGET_NAME) \
  or abort("#{TARGET_NAME} group not found in project navigator")

sources_phase = test_target.source_build_phase

# --- 1. Remove stale file references (file deleted on disk) ---
stale_refs = tests_group.files.select do |ref|
  abs = File.join(TESTS_DIR, ref.path)
  !File.exist?(abs)
end

stale_refs.each do |ref|
  puts "  Removing stale reference: #{ref.path}"
  # Remove from Sources build phase
  sources_phase.files_references.delete(ref)
  # Remove from group
  ref.remove_from_project
end

# --- 2. Add new files found on disk ---
existing_paths = tests_group.files.map(&:path)
Dir.glob(File.join(TESTS_DIR, '*.swift')).sort.each do |abs_path|
  filename = File.basename(abs_path)
  next if existing_paths.include?(filename)

  puts "  Adding new source: #{filename}"
  ref = tests_group.new_file(filename)
  sources_phase.add_file_reference(ref)
end

project.save
puts "✓ #{TARGET_NAME} sources synced."
