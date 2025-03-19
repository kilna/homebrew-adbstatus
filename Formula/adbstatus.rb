class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  license "MIT"
  head "https://github.com/kilna/adbstatus.git", branch: "main"

  depends_on "python@3"
  depends_on "sleepwatcher"

  def install
    # Get the Python version dynamically
    python = Formula["python@3"].opt_bin/"python3"
    pip = Formula["python@3"].opt_bin/"pip3"
    
    # Check Python version
    python_version = Utils.safe_popen_read(python, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_version.chomp!
    
    if Gem::Version.new(python_version) < Gem::Version.new("3.8")
      odie "Python 3.8 or newer is required but you have #{python_version}"
    end
    
    # Set up the target directory for installation
    site_packages = libexec/"lib/python#{python_version}/site-packages"
    ENV.prepend_create_path "PYTHONPATH", site_packages
    
    # Install the package
    system pip, "install", "--prefix=#{libexec}", "."
    
    # Create bin stubs
    bin_paths = Dir["#{libexec}/bin/*"]
    bin.install_symlink(bin_paths)
    
    # Create wrapped bin scripts that set correct PYTHONPATH
    bin_paths.each do |bin_path|
      bin_name = File.basename(bin_path)
      (bin/bin_name).write_env_script bin_path,
        PYTHONPATH: "#{site_packages}:#{ENV["PYTHONPATH"]}"
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
    # Check version output contains a version number
    assert_match(/\d+\.\d+\.\d+/, shell_output("#{bin}/adbstatus -v"))
  end
end

