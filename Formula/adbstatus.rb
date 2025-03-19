class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  license "MIT"
  
  depends_on "python@3"
  depends_on "sleepwatcher"

  def install
    # Install source files directly
    libexec.install "adbstatus"
    
    # Create bin scripts that add libexec to Python path
    commands = {
      "adbstatus" => "core.ADBStatus",
      "adbstatus-server" => "server.ADBStatusServer",
      "adbstatus-monitor" => "monitor.ADBStatusMonitor"
    }
    
    commands.each do |cmd, path_class|
      (bin/cmd).write <<~EOS
        #!/usr/bin/env python3
        import sys; sys.path.insert(0, "#{libexec}"); from adbstatus.#{path_class.split(".")[0]} import #{path_class.split(".")[1]}; sys.exit(#{path_class.split(".")[1]}.main())
      EOS
      chmod 0755, bin/cmd
    end
    
    # Create configuration directories
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files
    Dir["etc/*.yml"].each do |config|
      dest = etc/"adbstatus"/File.basename(config)
      dest.write(File.read(config)) unless dest.exist?
    end
    
    # Generate SSL certificates if needed
    ssl_cert = etc/"adbstatus/ssl/adbstatus.crt"
    ssl_key = etc/"adbstatus/ssl/adbstatus.key"
    
    unless ssl_cert.exist? && ssl_key.exist?
      system "openssl", "req", "-new", "-newkey", "rsa:2048", "-days", "3650", 
             "-nodes", "-x509", "-subj", "/CN=adbstatus", 
             "-keyout", ssl_key, "-out", ssl_cert
      chmod 0644, ssl_cert
      chmod 0600, ssl_key
    end
  end

  service do
    run [opt_bin/"adbstatus-server", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-server.log"
    error_log_path var/"log/adbstatus-server.log"
  end

  service do
    name "adbstatus-monitor"
    run [opt_bin/"adbstatus-monitor", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-monitor.log"
    error_log_path var/"log/adbstatus-monitor.log"
  end
  
  def caveats
    <<~EOS
      Python dependencies required: tomli (for Python <3.11), psutil, pyyaml
      Install with: pip install tomli psutil pyyaml
    EOS
  end

  test do
    assert_predicate bin/"adbstatus", :exist?
  end
end

