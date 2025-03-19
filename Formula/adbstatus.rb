class Adbstatus < Formula
  include Language::Python::Virtualenv
  
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  
  license "MIT"
  
  # Use Python 3 without specifying a minor version
  depends_on "python@3"
  depends_on "sleepwatcher"
  
  # Define Python version requirement without installing specific version
  uses_from_macos "python", since: :catalina

  def install
    # Check Python version meets minimum requirement
    python = Formula["python@3"].opt_bin/"python3"
    python_version = Utils.safe_popen_read(python, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_version.chomp!
    
    if Gem::Version.new(python_version) < Gem::Version.new("3.8")
      odie "Python 3.8 or newer is required but you have #{python_version}"
    end
    
    # Create a debug script that will run pip with more verbose output
    debug_py = buildpath/"debug_install.py"
    debug_py.write <<~EOS
      #!/usr/bin/env python3
      import os
      import sys
      import subprocess
      import time
      
      # Write to a log file in the user's home directory
      log_path = os.path.expanduser("~/adbstatus_install_debug.log")
      
      with open(log_path, "w") as f:
          f.write(f"=== ADBStatus Installation Debug Log ===\\n")
          f.write(f"Date: {time.ctime()}\\n")
          f.write(f"Python: {sys.executable}\\n")
          f.write(f"Version: {sys.version}\\n")
          f.write(f"Working dir: {os.getcwd()}\\n\\n")
          
          # Check if required files exist
          f.write("== Repository contents ==\\n")
          for root, dirs, files in os.walk("."):
              for file in files:
                  if file.endswith(".py") or file in ["pyproject.toml", "setup.py", "setup.cfg"]:
                      f.write(f"{os.path.join(root, file)}\\n")
          
          # Check if package is importable
          f.write("\\n== Package structure ==\\n")
          if os.path.exists("adbstatus"):
              f.write("adbstatus directory exists\\n")
              # Print contents
              for root, dirs, files in os.walk("adbstatus"):
                  for file in files:
                      if file.endswith(".py"):
                          f.write(f"{os.path.join(root, file)}\\n")
          else:
              f.write("ERROR: adbstatus directory not found!\\n")
          
          # Attempt installation with pip with extra verbosity
          f.write("\\n== Running pip install ==\\n")
          cmd = [
              sys.executable, 
              "-m", 
              "pip", 
              "install", 
              "--verbose", 
              "."
          ]
          f.write(f"Command: {' '.join(cmd)}\\n\\n")
          
          try:
              process = subprocess.Popen(
                  cmd,
                  stdout=subprocess.PIPE,
                  stderr=subprocess.PIPE,
                  text=True
              )
              
              # Capture output in real-time
              for line in process.stdout:
                  f.write(f"OUT: {line}")
              
              for line in process.stderr:
                  f.write(f"ERR: {line}")
              
              process.wait()
              f.write(f"\\nExit code: {process.returncode}\\n")
          except Exception as e:
              f.write(f"Exception during pip install: {e}\\n")
              import traceback
              f.write(traceback.format_exc())
      
      print(f"Debug log written to {log_path}")
    EOS
    
    # Make the debug script executable
    chmod 0755, debug_py
    
    # Run the debug script to gather information
    system python, debug_py.to_s
    
    # Now proceed with the proper virtual environment installation
    begin
      # Try installing with virtualenv
      virtualenv_install_with_resources
    rescue => e
      # If the virtualenv installation fails, capture the error
      opoo "Virtualenv installation failed: #{e}"
      opoo "See ~/adbstatus_install_debug.log for detailed error information"
      raise
    end
    
    # Create configuration directories
    (etc/"adbstatus").mkpath
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files if they exist
    if File.exist?("etc/server.yml")
      (etc/"adbstatus").install "etc/server.yml" unless (etc/"adbstatus/server.yml").exist?
    end
    
    if File.exist?("etc/monitor.yml")
      (etc/"adbstatus").install "etc/monitor.yml" unless (etc/"adbstatus/monitor.yml").exist?
    end
    
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
    # Simple test that just checks if the binaries exist
    assert_predicate bin/"adbstatus", :exist?
  end
end

