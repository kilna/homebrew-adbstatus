class Adbstatus < Formula
  include Language::Python::Virtualenv
  
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  
  license "MIT"
  
  depends_on "python@3"
  depends_on "sleepwatcher"
  
  resource "psutil" do
    url "https://files.pythonhosted.org/packages/fe/8c/284d8d946e21c37bf0a7b59facf871470e35d7a468abbfbc31ef6d42099f/psutil-5.9.8.tar.gz"
    sha256 "6be126e3225486dff286a8fb9a06246a5253f4c7c53b475ea5f5ac934e64194c"
  end

  resource "pyyaml" do
    url "https://files.pythonhosted.org/packages/cd/e5/af35f7ea75cf72f2cd079c95ee16797de7cd71f29ea7c68ae5ce7be1eda0/PyYAML-6.0.1.tar.gz"
    sha256 "bfdf460b1736c775f2ba9f6a92bca30bc2095067b8a9d77876d1fad6cc3b4a43"
  end

  resource "tomli" do
    url "https://files.pythonhosted.org/packages/c0/3f/d7af728f075fb08564c5949a9c95e44352e23dee646869fa104a3b2060a3/tomli-2.0.1.tar.gz"
    sha256 "de526c12914f0c550d15924c62d72abc48d6fe7364aa87328337a31007fe8a4f"
  end

  def install
    virtualenv_create(libexec, "python3")
    
    resources.each do |r|
      r.stage do
        system libexec/"bin/pip", "install", "-v", "--no-deps", 
               "--ignore-installed", "./"
      end
    end
    
    # Install directly from source directory
    system libexec/"bin/pip", "install", "-v", "--no-deps", "--ignore-installed", "./"
    
    # Create configuration directories
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files
    (etc/"adbstatus").install Dir["etc/*.yml"]
    
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
    
    # Create bin stubs
    bin.install_symlink Dir["#{libexec}/bin/adbstatus*"]
  end

  # Server service
  service do
    name "adbstatus-server"
    run [opt_bin/"adbstatus-server", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-server.log"
    error_log_path var/"log/adbstatus-server.log"
  end

  # Monitor service
  service do
    name "adbstatus-monitor"
    run [opt_bin/"adbstatus-monitor", "start", "-f"]
    keep_alive true
    log_path var/"log/adbstatus-monitor.log"
    error_log_path var/"log/adbstatus-monitor.log"
  end

  def caveats
    <<~EOS
      Dependencies: Python 3.8+, tomli (for Python <3.11), psutil, pyyaml
      If needed: pip install tomli psutil pyyaml
    EOS
  end

  test do
    assert_predicate bin/"adbstatus", :exist?
  end
end

