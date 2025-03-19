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
    
    # Print directory structure and pyproject.toml contents for debugging
    puts "Original pyproject.toml content:"
    system "cat", "pyproject.toml"
    
    # Install the package
    system venv/"bin/pip", "install", "."
    
    # Find the site-packages directory where the package was installed
    site_packages = Dir["#{venv}/lib/python*/site-packages"].first
    if site_packages
      package_dir = "#{site_packages}/adbstatus"
      
      puts "\nSite packages directory: #{site_packages}"
      puts "Package directory: #{package_dir}"
      
      # Copy pyproject.toml to the installed package directory
      mkdir_p package_dir unless File.directory?(package_dir)
      if File.exist?("pyproject.toml")
        cp "pyproject.toml", package_dir
        puts "Copied pyproject.toml to package directory: #{package_dir}/pyproject.toml"
      else
        puts "Warning: pyproject.toml not found in current directory"
      end
    else
      puts "Warning: Could not find site-packages directory"
    end
    
    # Create a modified copy of __init__.py that outputs debug info
    init_py = Dir["#{site_packages}/adbstatus/__init__.py"].first
    if init_py && File.exist?(init_py)
      init_content = File.read(init_py)
      debug_init = init_content.gsub(/for path in \[/, 
        "print('Debug: Looking for pyproject.toml in:')\n    for path in [")
      debug_init = debug_init.gsub(/if path.exists\(\):/, 
        "print(f'  Checking {path} (exists: {path.exists()})')\n    if path.exists():")
      File.write(init_py, debug_init)
      puts "Added debug output to __init__.py"
    end
    
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
    
    # Create a debug script
    (bin/"adbstatus-debug").write <<~EOS
      #!/bin/bash
      echo "Debugging ADBStatus installation:"
      echo "Python version: $(#{venv}/bin/python3 --version)"
      echo "Package location:"
      #{venv}/bin/python3 -c "import adbstatus; print(adbstatus.__file__)"
      echo "pyproject.toml search paths:"
      #{venv}/bin/python3 -c "import adbstatus, pathlib; print('Parent dir:', pathlib.Path(adbstatus.__file__).parent); print('Parent of parent:', pathlib.Path(adbstatus.__file__).parent.parent)"
      echo "Files in package directory:"
      ls -la $(#{venv}/bin/python3 -c "import adbstatus, pathlib; print(pathlib.Path(adbstatus.__file__).parent)")
      echo "Contents of pyproject.toml (if found):"
      cat $(#{venv}/bin/python3 -c "import adbstatus, pathlib; print(pathlib.Path(adbstatus.__file__).parent / 'pyproject.toml')") 2>/dev/null || echo "File not found"
    EOS
    chmod 0755, bin/"adbstatus-debug"
    
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
        
      If you're having issues with pyproject.toml, run:
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
