class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  
  license "MIT"
  
  # Only depend on sleepwatcher, not Python
  depends_on "sleepwatcher"
  
  def install
    # Install source code and create config directories
    libexec.install "adbstatus"
    (etc/"adbstatus/ssl").mkpath
    
    # Install configs if they don't exist
    Dir["etc/*.yml"].each do |config_file|
      dest = etc/"adbstatus"/File.basename(config_file)
      dest.write(File.read(config_file)) unless dest.exist?
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
    
    # Create executable scripts
    ["adbstatus", "adbstatus-server", "adbstatus-monitor"].each do |cmd|
      module_path = cmd == "adbstatus" ? "core" : cmd.sub("adbstatus-", "")
      class_name = cmd.sub("adbstatus", "ADBStatus").sub("-", "")
      
      (bin/cmd).write <<~PYTHON
        #!/usr/bin/env python3
        import sys; sys.path.insert(0, "#{libexec}"); from adbstatus.#{module_path} import #{class_name}; sys.exit(#{class_name}.main())
      PYTHON
      chmod 0755, bin/cmd
    end
  end

  # Server service
  service do
    name "adbstatus-server"
    run [opt_bin/"adbstatus-server", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-server.log"
    error_log_path var/"log/adbstatus-server.log"
  end

  # Monitor service
  service do
    name "adbstatus-monitor"
    run [opt_bin/"adbstatus-monitor", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-monitor.log"
    error_log_path var/"log/adbstatus-monitor.log"
  end

  def caveats
    <<~EOS
      Dependencies: Python 3.8+, tomli (for Python <3.11), psutil, pyyaml
      If needed: pip install tomli psutil pyyaml
    EOS
  end

  test do
    assert_predicate bin/"adbstatus", :exist?
  end
end

