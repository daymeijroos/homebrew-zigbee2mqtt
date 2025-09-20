class Zigbee2mqtt < Formula
  desc "Zigbee2MQTT – bridge between Zigbee devices and MQTT"
  homepage "https://www.zigbee2mqtt.io/"
  url "https://github.com/Koenkk/zigbee2mqtt/archive/refs/tags/1.40.2.tar.gz"
  sha256 "17b2103efcd7603e05238b97fbe91d9b256dc1a10aba2174e82be9dfb7001176"
  license "MIT"

  depends_on "node"
  depends_on "mosquitto"

  def install
    prefix.install Dir["*"]
    cd prefix do
      system "npm", "ci", "--production"
    end

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

    device_name = `ioreg -p IOUSB -l | grep -iE '("USB Product Name"|"kUSBProductString") *= *".*zigbee.*"' | awk -F'"' '{print $4}'`.strip

    if device_name.empty?
      opoo "No Zigbee USB device detected via ioreg. You'll need to set the serial.port manually in configuration.yaml"
      device_name = "ttyUSB0"
    end

    port = `ls /dev/tty.* 2>/dev/null | grep -i "$(echo #{device_name} | tr ' ' '.')"` rescue ""
    port.strip!

    if port.empty?
      opoo "Could not automatically determine serial port for Zigbee device '#{device_name}'."
      port = "/dev/ttyUSB0"
    end

    unless config_file.exist?
      config_file.write <<~EOS
        homeassistant: false
        permit_join: true
        mqtt:
          base_topic: zigbee2mqtt
          server: 'mqtt://localhost'
        serial:
          port: '#{port}'
        frontend:
          enabled: true  
          port: 9999
      EOS
    end
  end

  service do
    run [opt_bin/"zigbee2mqtt"]
    keep_alive true
    working_dir var/"zigbee2mqtt"
    log_path var/"log/zigbee2mqtt.log"
    error_log_path var/"log/zigbee2mqtt.error.log"
  end

  test do
    system "#{bin}/zigbee2mqtt", "--version"
  end
end
