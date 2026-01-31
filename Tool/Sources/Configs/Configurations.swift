import Foundation

private var teamIDPrefix: String {
    Bundle.main.infoDictionary?["TEAM_ID_PREFIX"] as? String ?? ""
}

private var bundleIdentifierBase: String {
    Bundle.main.infoDictionary?["BUNDLE_IDENTIFIER_BASE"] as? String ?? ""
}

public var userDefaultSuiteName: String {
    "\(teamIDPrefix)group.\(bundleIdentifierBase).prefs"
}

/// Dedicated preference domain for workspace-level auto-approval.
///
/// This is intentionally separate from `userDefaultSuiteName` so we can keep
/// auto-approval state isolated from general preferences.
public var autoApprovalUserDefaultSuiteName: String {
    "\(teamIDPrefix)group.\(bundleIdentifierBase).autoApproval.prefs"
}
