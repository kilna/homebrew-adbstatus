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
    
    # Create a virtualenv
    venv = virtualenv_create(libexec, python)
    
    # Install directly from Git URL instead of local directory
    system venv.pip_install("git+https://github.com/kilna/adbstatus.git@main")
    
    # Symlink all the binaries
    bin_paths = Dir["#{libexec}/bin/*"]
    bin.install_symlink(bin_paths)
    
    # Create configuration directories
    (etc/"adbstatus").mkpath
    (etc/"adbstatus/ssl").mkpath
    
    # Copy config files from the cloned repo
    repo_dir = buildpath
    
    if File.exist?(repo_dir/"etc/server.yml")
      (etc/"adbstatus").install repo_dir/"etc/server.yml" unless (etc/"adbstatus/server.yml").exist?
    end
    
    if File.exist?(repo_dir/"etc/monitor.yml")
      (etc/"adbstatus").install repo_dir/"etc/monitor.yml" unless (etc/"adbstatus/monitor.yml").exist?
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

