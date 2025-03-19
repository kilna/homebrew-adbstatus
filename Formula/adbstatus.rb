class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  license "MIT"
  
  depends_on "python@3"
  depends_on "sleepwatcher"

  def install
    # Create a virtual environment
    venv = libexec
    system Formula["python@3"].opt_bin/"python3", "-m", "venv", venv
    
    # Install dependencies and package
    system venv/"bin/pip", "install", "psutil", "pyyaml", "tomli"
    system venv/"bin/pip", "install", "-e", "."
    
    # Link the executables
    bin.install_symlink Dir["#{venv}/bin/adbstatus*"]
    
    # Set up configuration
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files if they don't exist
    Dir["etc/*.yml"].each do |config|
      dest = etc/"adbstatus"/File.basename(config)
      dest.write(File.read(config)) unless dest.exist?
    end
    
    # Generate SSL certificates if needed
    ssl_cert = etc/"adbstatus/ssl/adbstatus.crt"
    ssl_key = etc/"adbstatus/ssl/adbstatus.key"
    
    unless ssl_cert.exist? && ssl_key.exist?
      system "openssl", "req", "-new", "-newkey", "rsa:2048", "-days", "3650", 
             "-nodes", "-x509", "-subj", "/CN=adbstatus", 
             "-keyout", ssl_key, "-out", ssl_cert
      chmod 0644, ssl_cert
      chmod 0600, ssl_key
    end
  end

  service do
    run [opt_bin/"adbstatus-server", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-server.log"
    error_log_path var/"log/adbstatus-server.log"
  end

  service do
    run [opt_bin/"adbstatus-monitor", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-monitor.log"
    error_log_path var/"log/adbstatus-monitor.log"
  end
  
  def caveats
    <<~EOS
      Python dependencies required: tomli (for Python <3.11), psutil, pyyaml
      Install with: pip install tomli psutil pyyaml
    EOS
  end

  test do
    assert_predicate bin/"adbstatus", :exist?
  end
end

