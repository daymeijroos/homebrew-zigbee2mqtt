class Zigbee2mqtt < Formula
  desc "Zigbee2MQTT – bridge between Zigbee devices and MQTT"
  homepage "https://www.zigbee2mqtt.io/"
  url "https://github.com/Koenkk/zigbee2mqtt/archive/refs/tags/1.40.2.tar.gz"
  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"  # Replace with actual sha256
  license "MIT"

  depends_on "node"
  depends_on "mosquitto"

  def install
    # Install source code
    prefix.install Dir["*"]

    # Install Node dependencies
    cd prefix do
      system "npm", "ci", "--production"
    end

    # Create a wrapper script to launch Zigbee2MQTT
    (bin/"zigbee2mqtt").write <<~EOS
      #!/bin/bash
      exec "#{Formula["node"].opt_bin}/node" "#{prefix}/index.js" "$@"
    EOS
    chmod 0755, bin/"zigbee2mqtt"
  end

  def post_install
    require "fileutils"

    config_dir = HOMEBREW_PREFIX/"var/zigbee2mqtt"
    config_file = config_dir/"configuration.yaml"

    FileUtils.mkdir_p config_dir

    # Try to detect Zigbee USB device using ioreg
    device_name = `ioreg -p IOUSB -l | grep -iE '"Product" = ".*zigbee.*"' | awk -F'"' '{print $4}'`.strip

    if device_name.empty?
      odie "No Zigbee device found via ioreg. Please edit #{config_file} manually and set serial.port"
    end

    port = `ls /dev/tty.* | grep -i "$(echo #{device_name} | tr ' ' '.')"` rescue ""
    port.strip!

    if port.empty?
      odie "Could not detect serial port for Zigbee device. Please edit #{config_file} manually."
    end

    # Only write config if it doesn't already exist
    unless config_file.exist?
      config_file.write <<~EOS
        homeassistant: false
        permit_join: true
        mqtt:
          base_topic: zigbee2mqtt
          server: 'mqtt://localhost'
        serial:
          port: '#{port}'
      EOS
    end
  end

  plist_options manual: "zigbee2mqtt"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_bin}/zigbee2mqtt</string>
          </array>
          <key>WorkingDirectory</key>
          <string>#{var}/zigbee2mqtt</string>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>StandardOutPath</key>
          <string>#{var}/log/zigbee2mqtt.log</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/zigbee2mqtt.error.log</string>
        </dict>
      </plist>
    EOS
  end

  test do
    assert_match "Zigbee2MQTT", shell_output("#{bin}/zigbee2mqtt --version 2>&1", 1)
  end
end

