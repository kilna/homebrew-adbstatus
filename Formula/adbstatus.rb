class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  license "MIT"
  
  depends_on "python@3"
  depends_on "sleepwatcher"

  def install
    # Create a virtual environment
    venv = libexec
    system Formula["python@3"].opt_bin/"python3", "-m", "venv", venv
    
    # Install dependencies
    system venv/"bin/pip", "install", "psutil", "pyyaml", "tomli"
    
    # Install the package directly (not in editable mode)
    # This ensures proper package installation
    system venv/"bin/pip", "install", "."
    
    # Remove any existing scripts
    rm_f bin/"adbstatus" if File.exist?(bin/"adbstatus")
    rm_f bin/"adbstatus-server" if File.exist?(bin/"adbstatus-server")
    rm_f bin/"adbstatus-monitor" if File.exist?(bin/"adbstatus-monitor")
    
    # Create simple wrapper scripts that use the virtualenv Python
    (bin/"adbstatus").write <<~EOS
      #!/bin/bash
      exec "#{venv}/bin/python3" -m adbstatus.core "$@"
    EOS
    
    (bin/"adbstatus-server").write <<~EOS
      #!/bin/bash
      exec "#{venv}/bin/python3" -m adbstatus.server "$@"
    EOS
    
    (bin/"adbstatus-monitor").write <<~EOS
      #!/bin/bash
      exec "#{venv}/bin/python3" -m adbstatus.monitor "$@"
    EOS
    
    # Make the scripts executable
    chmod 0755, bin/"adbstatus"
    chmod 0755, bin/"adbstatus-server" 
    chmod 0755, bin/"adbstatus-monitor"
    
    # Set up configuration directories
    (etc/"adbstatus/ssl").mkpath
    (var/"log/adbstatus").mkpath
    (var/"run/adbstatus").mkpath
    
    # Process and install config files
    Dir["etc/*.yml"].each do |config_file|
      filename = File.basename(config_file)
      dest = etc/"adbstatus"/filename
      
      # Skip if file already exists
      unless dest.exist?
        # Read the template content
        content = File.read(config_file)
        
        # Adjust paths for Homebrew
        brew_content = content.dup
        
        # Replace log file paths
        brew_content.gsub!(/file:\s*["']~\/Library\/Logs\/adbstatus-(\w+)\.log["']/, "file: \"#{var}/log/adbstatus/\\1.log\"")
        
        # Replace PID file paths
        brew_content.gsub!(/pid_file:\s*["']~\/.adbstatus_(\w+)\.pid["']/, "pid_file: \"#{var}/run/adbstatus/\\1.pid\"")
        
        # Replace SSL certificate paths
        brew_content.gsub!(/cert_dir:\s*["']\/usr\/local\/etc\/adbstatus\/ssl["']/, "cert_dir: \"#{etc}/adbstatus/ssl\"")
        brew_content.gsub!(/cert_dir:\s*["']\/opt\/homebrew\/etc\/adbstatus\/ssl["']/, "cert_dir: \"#{etc}/adbstatus/ssl\"")
        
        # Replace other hardcoded paths
        brew_content.gsub!(/["']\/usr\/local\/etc\/adbstatus["']/, "\"#{etc}/adbstatus\"")
        brew_content.gsub!(/["']\/opt\/homebrew\/etc\/adbstatus["']/, "\"#{etc}/adbstatus\"")
        
        # Replace any output log paths in shell commands
        brew_content.gsub!(/>>\s*\/tmp\/(\w+)\.log/, ">> #{var}/log/adbstatus/\\1.log")
        
        # Write the modified content
        dest.write(brew_content)
      end
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

  # Services with simplified options
  service do
    run [opt_bin/"adbstatus-server", "start"]
    working_dir HOMEBREW_PREFIX
    log_path var/"log/adbstatus/server.log"
    error_log_path var/"log/adbstatus/server.log"
  end

  service do
    run [opt_bin/"adbstatus-monitor", "start"]
    working_dir HOMEBREW_PREFIX
    log_path var/"log/adbstatus/monitor.log"
    error_log_path var/"log/adbstatus/monitor.log"
  end
  
  def caveats
    <<~EOS
      Python dependencies required: tomli (for Python <3.11), psutil, pyyaml
      Install with: pip install tomli psutil pyyaml
      
      To manage ADBStatus services:
      
        brew services start adbstatus    # Starts server and monitor
        brew services stop adbstatus     # Stops server and monitor
        
      For troubleshooting, try running directly:
      
        #{bin}/adbstatus-server start -f   # Run server in foreground
        #{bin}/adbstatus-monitor start -f  # Run monitor in foreground
        
      Configuration files are located at:
        #{etc}/adbstatus/
      
      Log files are located at:
        #{var}/log/adbstatus/server.log
        #{var}/log/adbstatus/monitor.log
    EOS
  end

  test do
    assert_predicate bin/"adbstatus", :exist?
  end
end
