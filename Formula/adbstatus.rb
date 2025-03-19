class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  license "MIT"
  
  depends_on "python@3.11"
  depends_on "sleepwatcher"

  def install
    # Create a virtual environment
    venv = libexec
    system Formula["python@3.11"].opt_bin/"python3", "-m", "venv", venv
    
    # Install dependencies
    system venv/"bin/pip", "install", "psutil", "pyyaml"
    
    # Install the package
    system venv/"bin/pip", "install", "."
    
    # Find the site-packages directory where the package was installed
    site_packages = Dir["#{venv}/lib/python*/site-packages"].first
    package_dir = "#{site_packages}/adbstatus" if site_packages
    
    # Copy pyproject.toml to multiple locations to ensure it's found
    if File.exist?("pyproject.toml") && package_dir && File.directory?(package_dir)
      cp "pyproject.toml", package_dir
      cp "pyproject.toml", site_packages if site_packages
      cp "pyproject.toml", venv
    end
    
    # Create a debug script
    (bin/"adbstatus-debug").write <<~EOS
      #!/bin/bash
      echo "=== ADBStatus Debug Info ==="
      echo "Python version: $(#{venv}/bin/python3 --version)"
      echo
      
      echo "=== Package Location ==="
      #{venv}/bin/python3 -c "import adbstatus; print(f'Package file: {adbstatus.__file__}')"
      
      echo
      echo "=== pyproject.toml Search Paths ==="
      #{venv}/bin/python3 -c "
      import os, sys
      from pathlib import Path
      import adbstatus
      
      pkg_dir = Path(adbstatus.__file__).parent
      parent_dir = pkg_dir.parent
      
      print(f'Package directory: {pkg_dir}')
      print(f'Parent directory: {parent_dir}')
      
      paths = [
          parent_dir / 'pyproject.toml',
          pkg_dir / 'pyproject.toml'
      ]
      
      for path in paths:
          print(f'Checking: {path}')
          print(f'  Exists: {path.exists()}')
          if path.exists():
              print(f'  Content: {path.read_text()[:100]}...')
      "
    EOS
    chmod 0755, bin/"adbstatus-debug"
    
    # Create wrapper scripts
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
    
    puts "\nInstallation complete. Run 'adbstatus-debug' to troubleshoot pyproject.toml issues."
  end

  # Services
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
      Python dependencies required: psutil, pyyaml
      Python 3.11 or newer is required.
      
      To manage ADBStatus services:
      
        brew services start adbstatus    # Starts both services
        brew services stop adbstatus     # Stops both services
        
      For troubleshooting, try running directly:
      
        #{bin}/adbstatus-server start -f   # Run server in foreground
        #{bin}/adbstatus-monitor start -f  # Run monitor in foreground
        
      To troubleshoot pyproject.toml issues, run:
        #{bin}/adbstatus-debug
        
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
