import AppKit
import Foundation
import Security

struct ProcessIdentityResolution {
    let applicationIdentity: ApplicationIdentity?
    let processDisplayName: String
}

enum ProcessIdentityResolver {
    static func resolve(pid: pid_t) -> ProcessIdentityResolution? {
        guard let executableURL = executableURL(for: pid) else {
            return nil
        }

        let processDisplayName = executableURL.lastPathComponent
        guard !processDisplayName.isEmpty else {
            return nil
        }

        return ProcessIdentityResolution(
            applicationIdentity: applicationIdentity(pid: pid, executableURL: executableURL),
            processDisplayName: processDisplayName
        )
    }

    private static func applicationIdentity(pid: pid_t, executableURL: URL) -> ApplicationIdentity? {
        guard
            let bundleURL = outermostApplicationURL(containing: executableURL),
            let bundle = Bundle(url: bundleURL),
            let bundleIdentifier = bundle.bundleIdentifier,
            !bundleIdentifier.isEmpty
        else {
            return nil
        }

        let runningApplication = NSRunningApplication(processIdentifier: pid)
        let runningApplicationName: String? = if
            runningApplication?.bundleIdentifier == bundleIdentifier,
            let runningBundleURL = runningApplication?.bundleURL,
            canonicalURL(runningBundleURL) == bundleURL
        {
            runningApplication?.localizedName
        } else {
            nil
        }

        let displayName = runningApplicationName
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent

        guard !displayName.isEmpty else {
            return nil
        }

        return ApplicationIdentity(
            groupKey: ApplicationIdentity.GroupKey(
                bundleURL: bundleURL,
                bundleIdentifier: bundleIdentifier
            ),
            displayName: displayName
        )
    }

    private static func executableURL(for pid: pid_t) -> URL? {
        let attributes = [kSecGuestAttributePid: NSNumber(value: pid)] as CFDictionary
        var dynamicCode: SecCode?
        guard
            SecCodeCopyGuestWithAttributes(nil, attributes, [], &dynamicCode) == errSecSuccess,
            let dynamicCode
        else {
            return nil
        }

        var staticCode: SecStaticCode?
        guard
            SecCodeCopyStaticCode(dynamicCode, [], &staticCode) == errSecSuccess,
            let staticCode
        else {
            return nil
        }

        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(staticCode, [], &information) == errSecSuccess,
            let information = information as? [CFString: Any]
        else {
            return nil
        }

        return information[kSecCodeInfoMainExecutable] as? URL
    }

    private static func outermostApplicationURL(containing executableURL: URL) -> URL? {
        var currentURL = canonicalURL(executableURL)
        var outermostApplicationURL: URL?

        while currentURL.path != "/" {
            if currentURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                outermostApplicationURL = currentURL
            }
            currentURL.deleteLastPathComponent()
        }

        return outermostApplicationURL.map(canonicalURL)
    }

    private static func canonicalURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
