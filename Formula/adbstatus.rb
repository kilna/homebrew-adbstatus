class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  license "MIT"
  head "https://github.com/kilna/adbstatus.git", branch: "main"

  depends_on "python@3.11"
  depends_on "sleepwatcher"

  def install
    # Install Python package with pip
    # This automatically creates the entry point scripts
    ENV["PYTHONPATH"] = libexec/"lib/python3.11/site-packages"
    system Formula["python@3.11"].opt_bin/"pip3", "install", *std_pip_args, "--target=#{libexec}/lib/python3.11/site-packages", "."
    
    # Create bin stubs that use the correct Python interpreter
    bin.install Dir["#{libexec}/bin/*"]
    bin.env_script_all_files(libexec/"bin", 
                            PATH: "#{Formula["python@3.11"].opt_bin}:#{ENV["PATH"]}",
                            PYTHONPATH: ENV["PYTHONPATH"])
    
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
    # Test that the binaries are installed and runnable
    system "#{bin}/adbstatus", "-v"
    system "#{bin}/adbstatus-server", "-v"
    system "#{bin}/adbstatus-monitor", "-v"
  end
end

