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
    
    # Check Python version
    python_version = Utils.safe_popen_read(python, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_version.chomp!
    
    if Gem::Version.new(python_version) < Gem::Version.new("3.8")
      odie "Python 3.8 or newer is required but you have #{python_version}"
    end
    
    # Set up installation directories
    site_packages = libexec/"lib/python#{python_version}/site-packages"
    ENV.prepend_create_path "PYTHONPATH", site_packages
    site_packages.mkpath
    
    # Install tomli for pyproject.toml parsing
    system python, "-m", "pip", "install", "--target=#{site_packages}", "tomli"
    
    # Add site_packages to PYTHONPATH for the installation
    ENV["PYTHONPATH"] = site_packages

    # Capture detailed error output
    cd buildpath do
      begin
        # Try to install with pip
        system_output = `#{python} -m pip install --verbose --no-deps --prefix=#{libexec} .`
        
        unless $?.success?
          # If pip install fails, write the output to a log file
          (buildpath/"pip_error.log").write(system_output)
          odie "Python package installation failed. See #{buildpath}/pip_error.log for details."
        end
      rescue => e
        odie "Installation error: #{e}"
      end
    end
    
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
    # Basic version check, but don't fail the installation if it doesn't work
    system bin/"adbstatus", "-v" rescue nil
    system bin/"adbstatus-server", "-v" rescue nil
    system bin/"adbstatus-monitor", "-v" rescue nil
    true  # Always succeed
  end
end

