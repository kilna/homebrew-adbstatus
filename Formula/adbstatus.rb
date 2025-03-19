class Adbstatus < Formula
  include Language::Python::Virtualenv
  
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  
  license "MIT"
  
  # Use the generic python@3 dependency
  depends_on "python@3"
  depends_on "sleepwatcher"
  
  # Define Python version requirement without installing specific version
  uses_from_macos "python", since: :catalina

  def install
    # Get the Python path - we'll find pip relative to this
    python = Formula["python@3"].opt_bin/"python3"
    
    # Check Python version
    python_version = Utils.safe_popen_read(python, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_version.chomp!
    
    ohai "Using Python #{python_version} at #{python}"
    
    if Gem::Version.new(python_version) < Gem::Version.new("3.8")
      odie "Python 3.8 or newer is required but you have #{python_version}"
    end
    
    # Create a virtual environment
    venv_dir = libexec
    system python, "-m", "venv", venv_dir
    
    # Get paths to binaries in the venv
    venv_python = "#{venv_dir}/bin/python"
    venv_pip = "#{venv_dir}/bin/pip"
    
    # Make sure pip is updated in the venv
    system venv_python, "-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel"
    
    # Install directly from the Git URL using the venv python
    # This avoids using the system pip which might be missing
    system venv_python, "-m", "pip", "install", "git+https://github.com/kilna/adbstatus.git@main"
    
    # Create bin stubs with Homebrew
    bin.install_symlink Dir["#{venv_dir}/bin/adbstatus*"]
    
    # Create configuration directories
    (etc/"adbstatus").mkpath
    (etc/"adbstatus/ssl").mkpath
    
    # Copy config files from the repository
    if Dir.exist?("etc")
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
    # Basic version check
    assert_match(/version/i, shell_output("#{bin}/adbstatus -v"))
  end
end

