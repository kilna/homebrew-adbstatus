class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  
  license "MIT"
  
  # Don't depend on Python - this avoids Homebrew forcing python@3.11
  # We'll find a suitable Python ourselves
  depends_on "sleepwatcher"

  def install
    # Find a suitable Python 3.8+ installation
    # Check for system Python first
    system_pythons = ["python3", "python3.8", "python3.9", "python3.10", 
                    "python3.11", "python3.12", "python3.13"]
    
    python_cmd = nil
    python_version = nil
    
    # Try system Python versions first
    system_pythons.each do |cmd|
      if system("which #{cmd} >/dev/null 2>&1")
        # Check if it's version 3.8+
        version_check = `#{cmd} -c 'import sys; print("{}.{}".format(sys.version_info.major, sys.version_info.minor))'`.chomp
        if version_check.match?(/^\d+\.\d+$/) && Gem::Version.new(version_check) >= Gem::Version.new("3.8")
          python_cmd = cmd
          python_version = version_check
          break
        end
      end
    end
    
    # If we didn't find a suitable Python, fail
    if python_cmd.nil?
      odie "No suitable Python 3.8+ found in your PATH. Please install Python 3.8 or newer."
    end
    
    ohai "Using Python #{python_version} (#{python_cmd})"
    
    # Create a virtual environment
    venv_dir = libexec
    system python_cmd, "-m", "venv", venv_dir
    
    # Get the path to Python and pip in the virtual environment
    venv_python = "#{venv_dir}/bin/python"
    venv_pip = "#{venv_dir}/bin/pip"
    
    # Make sure pip is up-to-date in the virtual environment
    system venv_python, "-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel"
    
    # Install adbstatus from Git
    system venv_python, "-m", "pip", "install", "git+https://github.com/kilna/adbstatus.git@main"
    
    # Install binaries to bin
    bin.install_symlink Dir["#{venv_dir}/bin/adbstatus*"]
    
    # Create configuration directories
    (etc/"adbstatus").mkpath
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files if they exist in the repo
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
    assert_predicate bin/"adbstatus", :exist?
  end
end

