class Adbstatus < Formula
  include Language::Python::Virtualenv
  
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  license "MIT"
  
  depends_on "python@3"
  depends_on "sleepwatcher"

  def install
    # Create a virtual environment with pip
    venv = libexec
    system Formula["python@3"].opt_bin/"python3", "-m", "venv", venv
    
    # Install pip into the virtualenv if it doesn't exist
    unless File.exist?("#{venv}/bin/pip")
      system Formula["python@3"].opt_bin/"python3", "-m", "ensurepip"
      system Formula["python@3"].opt_bin/"python3", "-m", "pip", "install", "--upgrade", "pip"
    end
    
    # Get the path to pip in the virtual environment
    venv_pip = "#{venv}/bin/pip"
    
    # Install dependencies directly using the virtualenv's pip
    system venv_pip, "install", "psutil", "pyyaml", "tomli"
    
    # Install the package itself (from the current directory)
    system venv_pip, "install", "-e", "."
    
    # Create bin stubs
    bin.install_symlink Dir["#{venv}/bin/adbstatus*"]
    
    # Create configuration directories
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files
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
    name "adbstatus-monitor"
    run [opt_bin/"adbstatus-monitor", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-monitor.log"
    error_log_path var/"log/adbstatus-monitor.log"
  end

  test do
    assert_predicate bin/"adbstatus", :exist?
  end
end

