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
    
    # Create debug directory and log file
    debug_dir = buildpath/"debug"
    debug_dir.mkpath
    debug_log = debug_dir/"install.log"
    
    # Log basic environment information
    debug_log.write("=== Environment Information ===\n")
    system "env", :out => [debug_log, "a"]
    
    # Check Python version
    debug_log.append_lines("\n=== Python Version ===")
    python_version = Utils.safe_popen_read(python, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_version.chomp!
    debug_log.append_lines("Python version: #{python_version}")
    
    if Gem::Version.new(python_version) < Gem::Version.new("3.8")
      debug_log.append_lines("Error: Python version too old")
      odie "Python 3.8 or newer is required but you have #{python_version}"
    end
    
    # Log repository contents
    debug_log.append_lines("\n=== Repository Contents ===")
    system "find", ".", "-type", "f", "-not", "-path", "./debug/*", "-ls", :out => [debug_log, "a"]
    
    # Log key file contents
    ["pyproject.toml", "setup.py", "setup.cfg"].each do |file|
      if File.exist?(file)
        debug_log.append_lines("\n=== #{file} Contents ===")
        debug_log.append_lines(File.read(file))
      end
    end
    
    # Set up installation directories
    site_packages = libexec/"lib/python#{python_version}/site-packages"
    ENV.prepend_create_path "PYTHONPATH", site_packages
    
    # Try installing with pip in verbose mode with full logging
    debug_log.append_lines("\n=== Pip Installation Attempt ===")
    
    # Create a detailed pip debugging script
    pip_debug_script = debug_dir/"pip_install.py"
    pip_debug_script.write <<~EOS
      import os
      import sys
      import subprocess
      import traceback
      
      def run_pip():
          print("Python executable:", sys.executable)
          print("Python version:", sys.version)
          print("Current directory:", os.getcwd())
          
          try:
              import pip
              print("Pip version:", pip.__version__)
          except ImportError:
              print("Pip not available as module")
          
          # Try pip install with all output captured
          cmd = [
              sys.executable, 
              "-m", 
              "pip",
              "install",
              "--verbose",
              "--prefix=#{libexec}",
              "."
          ]
          
          print("Running command:", " ".join(cmd))
          
          try:
              result = subprocess.run(
                  cmd,
                  stdout=subprocess.PIPE,
                  stderr=subprocess.PIPE,
                  text=True,
                  check=False
              )
              
              print("Return code:", result.returncode)
              print("STDOUT:\\n", result.stdout)
              print("STDERR:\\n", result.stderr)
              
              if result.returncode != 0:
                  # If that failed, try another approach
                  print("\\n\\nFirst attempt failed, trying alternate approach...")
                  alt_cmd = [
                      sys.executable,
                      "-m",
                      "pip",
                      "install",
                      "-e",
                      "."
                  ]
                  
                  print("Running command:", " ".join(alt_cmd))
                  
                  alt_result = subprocess.run(
                      alt_cmd,
                      stdout=subprocess.PIPE,
                      stderr=subprocess.PIPE,
                      text=True,
                      check=False
                  )
                  
                  print("Return code:", alt_result.returncode)
                  print("STDOUT:\\n", alt_result.stdout)
                  print("STDERR:\\n", alt_result.stderr)
                  
                  return alt_result.returncode
              
              return result.returncode
          except Exception as e:
              print("Exception during pip install:")
              print(traceback.format_exc())
              return 1
      
      if __name__ == "__main__":
          sys.exit(run_pip())
    EOS
    
    # Run the debug script and capture all output
    debug_log.append_lines("\n=== Pip Debug Script Output ===")
    system python, pip_debug_script.to_s, :out => [debug_log, "a"], :err => [debug_log, "a"]
    
    # Try direct installation with no bells and whistles
    debug_log.append_lines("\n=== Direct Installation Attempt ===")
    system python, "-m", "pip", "install", "--prefix=#{libexec}", ".", :out => [debug_log, "a"], :err => [debug_log, "a"]
    
    # At this point, check if installation succeeded
    if Dir["#{libexec}/bin/*"].empty?
      debug_log.append_lines("\n=== Installation Failed ===")
      opoo "Pip installation failed. See #{debug_log} for details."
      
      # Copy the debug log to a permanent location
      log_dir = HOMEBREW_LOGS/"adbstatus"
      log_dir.mkpath
      FileUtils.cp debug_log, log_dir/"install_failure.log"
      
      odie "Package installation failed. Debug log available at: #{log_dir}/install_failure.log"
    end
    
    # If we got here, the installation succeeded
    debug_log.append_lines("\n=== Installation Succeeded ===")
    
    # Create bin stubs with the right shebang
    bin.install Dir["#{libexec}/bin/*"]
    bin.each_child do |f|
      next unless f.file?
      inreplace f, %r{^#!.*python.*$}, "#!#{python}"
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
    
    # Copy debug log to installation for reference
    (libexec/"debug").mkpath
    FileUtils.cp debug_log, libexec/"debug/install.log"
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
    assert_predicate bin/"adbstatus", :exist?
  end
end

