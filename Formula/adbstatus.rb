class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  
  license "MIT"
  
  # Only depend on sleepwatcher, not Python
  depends_on "sleepwatcher"
  
  # This is the key part - create a resource that will be fetched directly
  resource "adbstatus" do
    url "https://github.com/kilna/adbstatus.git", branch: "main"
  end

  def install
    # Find a Python 3.8+ in the system
    python_cmd = nil
    ["python3.13", "python3.12", "python3.11", "python3.10", "python3.9", "python3.8", "python3"].each do |cmd|
      if system("which #{cmd} >/dev/null 2>&1") && 
         system("#{cmd} -c 'import sys; exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1")
        python_cmd = cmd
        break
      end
    end
    
    if python_cmd.nil?
      odie "No Python 3.8+ found in the system. Please install Python 3.8 or newer."
    end
    
    # Get the Python version
    python_version = `#{python_cmd} -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"`.strip
    ohai "Using system Python #{python_version} (#{python_cmd})"
    
    # Create a virtual environment
    venv_dir = libexec
    system python_cmd, "-m", "venv", venv_dir
    
    # Get venv paths
    venv_python = "#{venv_dir}/bin/python"
    
    # Ensure pip is up-to-date in the venv
    system venv_python, "-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel"
    
    # Install adbstatus directly from GitHub instead of local source
    # This is what we know works from your testing
    system venv_python, "-m", "pip", "install", "git+https://github.com/kilna/adbstatus.git@main"
    
    # Create bin stubs
    bin.install_symlink Dir["#{venv_dir}/bin/adbstatus*"]
    
    # Create configuration directories
    (etc/"adbstatus").mkpath
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files if they exist
    resource("adbstatus").stage do
      if File.exist?("etc/server.yml")
        (etc/"adbstatus").install "etc/server.yml" unless (etc/"adbstatus/server.yml").exist?
      end
      
      if File.exist?("etc/monitor.yml")
        (etc/"adbstatus").install "etc/monitor.yml" unless (etc/"adbstatus/monitor.yml").exist?
      end
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

