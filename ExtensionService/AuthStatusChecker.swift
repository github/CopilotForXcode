//
//  AuthStatusChecker.swift
//  ExtensionService
//
//  Responsible for checking the logged in status of the user.
//

import Foundation
import GitHubCopilotService

class AuthStatusChecker {
    var authService: GitHubCopilotAuthServiceType?

    public func updateStatusInBackground(notify: @escaping (_ status: String, _ isOk: Bool) -> Void) {
        Task {
            do {
                let status = try await self.getCurrentAuthStatus()
                await MainActor.run {
                    notify(status.description, status == .ok)
                }
            } catch {
                await MainActor.run {
                    notify("\(error)", false)
                }
            }
        }
    }

    func getCurrentAuthStatus() async throws -> GitHubCopilotAccountStatus {
        let service = try getAuthService()
        let status = try await service.checkStatus()
        return status
    }

    func getAuthService() throws -> GitHubCopilotAuthServiceType {
        if let service = authService { return service }
        let service = try GitHubCopilotService()
        authService = service
        return service
    }
}
