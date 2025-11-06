import Cocoa
import CGEventOverride
import Logger

class NESCustomMenu: NSMenu {
    weak var menuController: NESMenuController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override init(title: String) {
        super.init(title: title)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupMenuAppearance() {
        self.showsStateColumn = false
        self.allowsContextMenuPlugIns = false
    }
}
