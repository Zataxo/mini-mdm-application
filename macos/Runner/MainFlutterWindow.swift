import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    
    // 1. Set the initial window size when opened
    self.setFrame(NSRect(x: 0, y: 0, width: 1024, height: 768), display: true)
    
    // 2. HARD CONSTRAINT: Prevents dragging/resizing smaller than this box
    self.minSize = NSSize(width: 1024, height: 768) 
    
    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}
