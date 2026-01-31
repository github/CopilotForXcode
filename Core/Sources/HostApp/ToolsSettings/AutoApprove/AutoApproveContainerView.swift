// AutoApproveContainerView.swift
// Container view for the auto-approve feature in Tools Settings
// Created: 2026-01-08
//
// This view wraps EditsAutoApproveView in a VStack for layout.

import AppKit
import Logger
import SharedUIComponents
import SwiftUI

struct AutoApproveContainerView: View {
    @ObservedObject private var featureFlags = FeatureFlagManager.shared
    @ObservedObject private var copilotPolicy = CopilotPolicyManager.shared

    private var isAutoApprovalEnabled: Bool {
        featureFlags.isAgenModeAutoApprovalEnabled && copilotPolicy.isAgentModeAutoApprovalEnabled
    }

    var body: some View {
        VStack(spacing: 16) {
            if isAutoApprovalEnabled {
                EditsAutoApproveView()
                TerminalAutoApproveView()
                MCPAutoApproveView()
            } else {
                AutoApprovalDisableView()
            }
        }
        .padding(.bottom, 20)
    }
}
