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
    
    # Set up configuration directories
    (etc/"adbstatus/ssl").mkpath
    (var/"log/adbstatus").mkpath
    (var/"run/adbstatus").mkpath
    
    # Process and install config files
    Dir["etc/*.yml"].each do |config_file|
      filename = File.basename(config_file)
      dest = etc/"adbstatus"/filename
      
      # Skip if file already exists
      unless dest.exist?
        # Read the template content
        content = File.read(config_file)
        
        # Adjust paths for Homebrew
        brew_content = content.dup
        
        # Replace log file paths
        brew_content.gsub!(/file:\s*["']~\/Library\/Logs\/adbstatus-(\w+)\.log["']/, "file: \"#{var}/log/adbstatus/\\1.log\"")
        
        # Replace PID file paths
        brew_content.gsub!(/pid_file:\s*["']~\/.adbstatus_(\w+)\.pid["']/, "pid_file: \"#{var}/run/adbstatus/\\1.pid\"")
        
        # Replace SSL certificate paths
        brew_content.gsub!(/cert_dir:\s*["']\/usr\/local\/etc\/adbstatus\/ssl["']/, "cert_dir: \"#{etc}/adbstatus/ssl\"")
        brew_content.gsub!(/cert_dir:\s*["']\/opt\/homebrew\/etc\/adbstatus\/ssl["']/, "cert_dir: \"#{etc}/adbstatus/ssl\"")
        
        # Replace other hardcoded paths
        brew_content.gsub!(/["']\/usr\/local\/etc\/adbstatus["']/, "\"#{etc}/adbstatus\"")
        brew_content.gsub!(/["']\/opt\/homebrew\/etc\/adbstatus["']/, "\"#{etc}/adbstatus\"")
        
        # Replace any output log paths in shell commands
        brew_content.gsub!(/>>\s*\/tmp\/(\w+)\.log/, ">> #{var}/log/adbstatus/\\1.log")
        
        # Write the modified content
        dest.write(brew_content)
        
        # Check if paths were replaced
        ohai "Installing #{filename} to #{dest}"
        if brew_content != content
          ohai "Paths were adjusted for Homebrew in #{filename}"
        else
          opoo "No path adjustments were made in #{filename}"
        end
      else
        ohai "Config file #{filename} already exists, skipping"
      end
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
