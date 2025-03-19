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
    # Get Python executable
    python = Formula["python@3"].opt_bin/"python3"
    
    # Check Python version
    python_version = Utils.safe_popen_read(python, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_version.chomp!
    
    ohai "Using Python #{python_version} at #{python}"
    
    if Gem::Version.new(python_version) < Gem::Version.new("3.8")
      odie "Python 3.8 or newer is required but you have #{python_version}"
    end
    
    # Create the virtualenv using Homebrew's helper
    venv = virtualenv_create(libexec, python)
    
    # Install directly from Git URL
    # This uses the same pip install git+url approach that worked for you
    system venv.pip_install("git+https://github.com/kilna/adbstatus.git@main")
    
    # Install binaries to bin/ with Homebrew
    bin_paths = Dir["#{libexec}/bin/*"]
    bin_paths.reject! { |p| File.basename(p) =~ /^pip[0-9.]*$|^python[0-9.]*$|^wheel$|^setuptools$/ }
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
    assert_predicate bin/"adbstatus", :exist?
    # Basic version check
    assert_match(/version/i, shell_output("#{bin}/adbstatus -v"))
  end
end

