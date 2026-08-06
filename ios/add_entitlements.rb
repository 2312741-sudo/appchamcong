require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Create entitlements file
entitlements_path = 'Runner/Runner.entitlements'
unless File.exist?(entitlements_path)
  File.write(entitlements_path, <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>aps-environment</key>
        <string>development</string>
    </dict>
    </plist>
  PLIST
  )
end

# Add to project group
group = project.main_group.find_subpath('Runner', true)
file_ref = group.files.find { |f| f.path == 'Runner.entitlements' }
unless file_ref
  file_ref = group.new_file('Runner.entitlements')
end

# Update build settings
project.targets.each do |target|
  if target.name == 'Runner'
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
    end
  end
end

project.save
puts "Entitlements added successfully!"
