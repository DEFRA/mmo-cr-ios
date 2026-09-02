#!/usr/bin/env ruby
# One-off script to add the "Generate Precomputed Map Data" Run Script Build Phase to the
# record-catch target. Not part of the app itself — a dev-time project-setup tool, run once.
#
# Uses the `xcodeproj` gem to edit project.pbxproj programmatically (safer than hand-editing the
# raw pbxproj text), and positions the new phase as the very first build phase so the precomputed
# `.plist` resources exist on disk before the synchronized group's resource-copy planning runs.
require 'xcodeproj'

project_path = File.expand_path('../record-catch.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'record-catch' }
raise "record-catch target not found" unless target

phase_name = 'Generate Precomputed Map Data'
existing = target.build_phases.find { |p| p.respond_to?(:name) && p.name == phase_name }
if existing
  puts "Build phase '#{phase_name}' already exists — skipping."
else
  phase = target.new_shell_script_build_phase(phase_name)
  phase.shell_script = "\"$SRCROOT/scripts/generate-offline-map-data.sh\"\n"
  phase.input_paths = [
    '$(SRCROOT)/record-catch/Features/Map/Data/map.geojson',
    '$(SRCROOT)/record-catch/Features/Map/Data/subrectangles.geojson',
    '$(SRCROOT)/record-catch/Features/Map/Data/ports.geojson',
    '$(SRCROOT)/scripts/generate-offline-map-data.sh',
    '$(SRCROOT)/scripts/main.swift'
  ]
  phase.output_paths = [
    '$(SRCROOT)/record-catch/Features/Map/Data/map-precomputed.plist',
    '$(SRCROOT)/record-catch/Features/Map/Data/subrectangles-precomputed.plist',
    '$(SRCROOT)/record-catch/Features/Map/Data/ports-precomputed.plist'
  ]
  phase.show_env_vars_in_log = '0'

  # Move it to be the very first build phase (before Sources/Resources/Frameworks), so the
  # precomputed resources are on disk before Xcode plans what to copy into the app bundle.
  target.build_phases.delete(phase)
  target.build_phases.unshift(phase)

  puts "Added build phase '#{phase_name}' as the first phase of target '#{target.name}'."
end

project.save
puts "Saved #{project_path}"
