import Client
import Foundation
import Logger
import SharedUIComponents
import SwiftUI

struct AutoApprovalDisableView: View {
    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.body)
                    .foregroundColor(.gray)
                Text(
                    "Auto approval is disabled by your organization's policy. To enable it, please contact your administrator. [Get More Info about Copilot policies](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/manage-policies)"
                )
            }
        }
        .groupBoxStyle(
            CardGroupBoxStyle(
                backgroundColor: Color(nsColor: .textBackgroundColor)
            )
        )
    }
}
