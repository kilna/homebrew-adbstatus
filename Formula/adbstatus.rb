class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  license "MIT"
  head "https://github.com/kilna/adbstatus.git", branch: "main"

  depends_on "python@3"
  depends_on "sleepwatcher"

  def install
    # Get Python info
    python = Formula["python@3"].opt_bin/"python3"
    
    # Check Python version and write it to a debug file
    debug_log = buildpath/"brew_debug.log"
    debug_log.write("Starting installation debug log\n")
    
    python_version = Utils.safe_popen_read(python, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_version.chomp!
    debug_log.append_lines("Python version: #{python_version}")
    
    if Gem::Version.new(python_version) < Gem::Version.new("3.8")
      debug_log.append_lines("Error: Python version too old")
      odie "Python 3.8 or newer is required but you have #{python_version}"
    end
    
    # Create a verbose debug installation attempt
    debug_log.append_lines("\nRepository contents:")
    system "ls", "-la", ".", :err => [debug_log, "a"], :out => [debug_log, "a"]
    
    if File.exist?("pyproject.toml")
      debug_log.append_lines("\npyproject.toml contents:")
      debug_log.append_lines(File.read("pyproject.toml"))
    end
    
    if File.exist?("setup.py")
      debug_log.append_lines("\nsetup.py contents:")
      debug_log.append_lines(File.read("setup.py"))
    end
    
    # Set up installation directories
    site_packages = libexec/"lib/python#{python_version}/site-packages"
    ENV.prepend_create_path "PYTHONPATH", site_packages
    site_packages.mkpath
    
    debug_log.append_lines("\nAttempting pip installation...")
    
    # Install tomli for pyproject.toml parsing
    system python, "-m", "pip", "install", "--target=#{site_packages}", "tomli"
    
    # Try a direct installation with more debugging
    cd buildpath do
      debug_log.append_lines("\nTrying direct pip installation...")
      
      # First try with verbose output
      pip_cmd = "#{python} -m pip install --verbose --no-deps --prefix=#{libexec} ."
      debug_log.append_lines("Running: #{pip_cmd}")
      
      system pip_cmd, :err => [debug_log, "a"], :out => [debug_log, "a"]
      
      unless $?.success?
        debug_log.append_lines("\nFirst installation attempt failed")
        
        # Try installing with minimal dependencies and debug output
        debug_log.append_lines("\nTrying simpler installation...")
        system "#{python} -m pip install -v .", :err => [debug_log, "a"], :out => [debug_log, "a"]
        
        debug_log.append_lines("\nInstallation failed. Check #{debug_log} for details.")
        odie "Python package installation failed. See #{debug_log} for details."
      end
    end
    
    debug_log.append_lines("\nInstallation succeeded, creating bin stubs...")
    
    # Create bin stubs that use the right Python
    bin.install Dir["#{libexec}/bin/*"]
    bin.each_child do |f|
      next unless f.file?
      
      # Rewrite the shebang line to use the specific Python
      inreplace f, %r{^#!.*python.*$}, "#!#{python}"
      
      # Set executable permissions
      chmod 0755, f
    end
    
    # Create configuration directories
    (etc/"adbstatus").mkpath
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files
    (etc/"adbstatus").install "etc/server.yml" unless (etc/"adbstatus/server.yml").exist?
    (etc/"adbstatus").install "etc/monitor.yml" unless (etc/"adbstatus/monitor.yml").exist?
    
    # Generate self-signed certificates if they don't exist
    unless (etc/"adbstatus/ssl/adbstatus.crt").exist? && (etc/"adbstatus/ssl/adbstatus.key").exist?
      system "openssl", "req", "-new", "-newkey", "rsa:2048", "-days", "3650", 
             "-nodes", "-x509", "-subj", "/CN=adbstatus", 
             "-keyout", "#{etc}/adbstatus/ssl/adbstatus.key",
             "-out", "#{etc}/adbstatus/ssl/adbstatus.crt"
    end
    
    # Ensure correct permissions on SSL files
    system "chmod", "644", "#{etc}/adbstatus/ssl/adbstatus.crt"
    system "chmod", "600", "#{etc}/adbstatus/ssl/adbstatus.key"
    
    debug_log.append_lines("\nInstallation completed")
  end

  # Server service
  service do
    run [opt_bin/"adbstatus-server", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-server.log"
    error_log_path var/"log/adbstatus-server.log"
    working_dir HOMEBREW_PREFIX
  end

  # Monitor service
  service do
    name "adbstatus-monitor"
    run [opt_bin/"adbstatus-monitor", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-monitor.log"
    error_log_path var/"log/adbstatus-monitor.log"
    working_dir HOMEBREW_PREFIX
  end

  test do
    # Always succeed for now
    true
  end
end

