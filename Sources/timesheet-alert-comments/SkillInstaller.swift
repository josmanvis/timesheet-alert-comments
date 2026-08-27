import Foundation
import Combine

class SkillInstaller: ObservableObject {
    static let shared = SkillInstaller()
    
    @Published var availableSkills: [String] = []
    @Published var isFetching = false
    @Published var isInstalling = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    
    private let repoURL = "https://gitlab.com/your-org/your-repo.git"
    private let branch = "admin-skills"
    
    private var tempCloneURL: URL? {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("conf_client_opentok_react_skills_clone")
    }
    
    func fetchSkills() {
        guard let tempCloneURL = tempCloneURL else { return }
        
        DispatchQueue.main.async {
            self.isFetching = true
            self.errorMessage = nil
            self.successMessage = nil
            self.availableSkills = []
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            
            // Clean up old clone if it exists
            if fm.fileExists(atPath: tempCloneURL.path) {
                try? fm.removeItem(at: tempCloneURL)
            }
            
            // Clone repo
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["clone", "--depth", "1", "--branch", self.branch, self.repoURL, tempCloneURL.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    throw NSError(domain: "SkillInstaller", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Git clone failed. Ensure you have access to the repository."])
                }
                
                // Find skills
                let skillsDir = tempCloneURL.appendingPathComponent(".claude/skills")
                if !fm.fileExists(atPath: skillsDir.path) {
                    throw NSError(domain: "SkillInstaller", code: 404, userInfo: [NSLocalizedDescriptionKey: "Skills directory not found in repository."])
                }
                
                let contents = try fm.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: [.isDirectoryKey])
                let skills = contents.filter { url in
                    var isDir: ObjCBool = false
                    return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
                }.map { $0.lastPathComponent }.sorted()
                
                DispatchQueue.main.async {
                    self.availableSkills = skills
                    self.isFetching = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isFetching = false
                }
            }
        }
    }
    
    func installSkill(_ skillName: String) {
        guard let tempCloneURL = tempCloneURL else { return }
        
        DispatchQueue.main.async {
            self.isInstalling = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let sourceURL = tempCloneURL.appendingPathComponent(".claude/skills").appendingPathComponent(skillName)
            
            let homeURL = fm.homeDirectoryForCurrentUser
            let targetPaths = [
                homeURL.appendingPathComponent(".gemini/config/skills").appendingPathComponent(skillName),
                homeURL.appendingPathComponent(".claude/skills").appendingPathComponent(skillName)
            ]
            
            var successCount = 0
            
            for targetURL in targetPaths {
                do {
                    let parentDir = targetURL.deletingLastPathComponent()
                    if !fm.fileExists(atPath: parentDir.path) {
                        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    }
                    
                    if fm.fileExists(atPath: targetURL.path) {
                        try fm.removeItem(at: targetURL)
                    }
                    
                    try fm.copyItem(at: sourceURL, to: targetURL)
                    successCount += 1
                } catch {
                    print("Failed to install to \(targetURL.path): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.isInstalling = false
                if successCount > 0 {
                    self.successMessage = "Successfully installed '\(skillName)'"
                } else {
                    self.errorMessage = "Failed to install '\(skillName)'"
                }
            }
        }
    }
}
