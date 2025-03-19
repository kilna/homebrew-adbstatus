class Adbstatus < Formula
  include Language::Python::Virtualenv
  
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  license "MIT"
  
  depends_on "python@3"
  depends_on "sleepwatcher"
  
  resource "psutil" do
    url "https://files.pythonhosted.org/packages/b2/38/c4d87f8a0ad6067a65ba112f273560ae721f068631d6ca546b059fc14cf4/psutil-5.9.8.tar.gz"
    sha256 "6be126e3225486dff286a8fb9a06246a5253f4c7c53b475ea5f5ac934e64194c"
  end

  resource "PyYAML" do
    url "https://files.pythonhosted.org/packages/36/2b/61d51a2c4f25ef062ae3f74576b01638bebad5e045f747ff12643df63844/PyYAML-6.0.tar.gz"
    sha256 "68fb519c14306fec9720a2a5b45bc9f0c8d1b9c72adf45c37baedfcd949c35a2"
  end

  resource "tomli" do
    url "https://files.pythonhosted.org/packages/c0/3f/d7af728f075fb08564c5949a9c95e44352e23dee646869fa104a3b2060a3/tomli-2.0.1.tar.gz"
    sha256 "de526c12914f0c550d15924c62d72abc48d6fe7364aa87328337a31007fe8a4f"
  end

  def install
    virtualenv_install_with_resources
    
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

