class Adbstatus < Formula
  desc "Android Debug Bridge (ADB) device monitor with sleep/wake support"
  homepage "https://github.com/kilna/adbstatus"
  
  head "https://github.com/kilna/adbstatus.git", branch: "main"
  
  license "MIT"
  
  # Only depend on sleepwatcher
  depends_on "sleepwatcher"
  
  # Skip :python@3 dependency completely
  
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
    # Find Python 3.8+ in PATH
    pythons = ENV["PATH"].split(":").map { |p| Dir["#{p}/python3*"] }.flatten.select do |py|
      next unless File.executable?(py)
      version = `#{py} -c "import sys; print('{}.{}'.format(*sys.version_info[:2]))"`.strip
      next unless version.match?(/^\d+\.\d+$/)
      Gem::Version.new(version) >= Gem::Version.new("3.8")
    end
    
    if pythons.empty?
      pythons = Dir["/usr/bin/python3*", "/usr/local/bin/python3*"].select do |py|
        next unless File.executable?(py)
        version = `#{py} -c "import sys; print('{}.{}'.format(*sys.version_info[:2]))"`.strip
        next unless version.match?(/^\d+\.\d+$/)
        Gem::Version.new(version) >= Gem::Version.new("3.8")
      end
    end
    
    if pythons.empty?
      odie "No Python 3.8+ found in PATH or standard locations. Please install Python 3.8+."
    end
    
    python = pythons.first
    python_version = `#{python} -c "import sys; print('{}.{}'.format(*sys.version_info[:2]))"`.strip
    ohai "Using Python #{python_version} at #{python}"
    
    # Install source code to libexec
    libexec.install "adbstatus"
    
    # Install dependencies manually
    resource_dir = buildpath/"vendor"
    resource_dir.mkpath
    
    resources.each do |r|
      r.stage do
        system python, "setup.py", "build"
        (resource_dir/r.name).mkpath
        cp_r ".", resource_dir/r.name
      end
    end
    
    # Create a site-packages directory
    site_packages = libexec/"lib/site-packages"
    site_packages.mkpath
    
    # Create .pth file to add resources to Python path
    (site_packages/"adbstatus.pth").write <<~EOS
      #{libexec}
      #{resource_dir}/psutil
      #{resource_dir}/pyyaml
      #{resource_dir}/tomli
    EOS
    
    # Create config directories and install configs
    (etc/"adbstatus/ssl").mkpath
    
    # Install config files
    Dir["etc/*.yml"].each do |f|
      dest = etc/"adbstatus"/File.basename(f)
      dest.write(File.read(f)) unless dest.exist?
    end
    
    # Generate SSL certificates if they don't exist
    ssl_cert = etc/"adbstatus/ssl/adbstatus.crt"
    ssl_key = etc/"adbstatus/ssl/adbstatus.key"
    
    unless ssl_cert.exist? && ssl_key.exist?
      system "openssl", "req", "-new", "-newkey", "rsa:2048", "-days", "3650", 
             "-nodes", "-x509", "-subj", "/CN=adbstatus", 
             "-keyout", ssl_key, "-out", ssl_cert
      chmod 0644, ssl_cert
      chmod 0600, ssl_key
    end
    
    # Create executable scripts
    {
      "adbstatus" => ["core", "ADBStatus"],
      "adbstatus-server" => ["server", "ADBStatusServer"],
      "adbstatus-monitor" => ["monitor", "ADBStatusMonitor"]
    }.each do |cmd, (mod, cls)|
      (bin/cmd).write <<~PYTHON
        #!/usr/bin/env python3
        import os, sys
        sys.path.insert(0, "#{site_packages}")
        sys.path.insert(0, "#{libexec}")
        #{resources.map { |r| "sys.path.insert(0, \"#{resource_dir}/#{r.name}\")" }.join("\n")}
        
        from adbstatus.#{mod} import #{cls}
        sys.exit(#{cls}.main())
      PYTHON
      chmod 0755, bin/cmd
    end
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
      This formula requires Python 3.8+ to be installed on your system.
      It will use the first Python 3.8+ found in your PATH.
    EOS
  end

  test do
    assert_predicate bin/"adbstatus", :exist?
  end
end

