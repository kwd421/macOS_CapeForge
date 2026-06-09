import SwiftUI

@main
struct CursieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var localization = LocalizationController.shared

    init() {
        if CommandLine.arguments.contains("--cursor-agent") {
            CursorAgentRuntime.shared.run()
        }
        if let exitCode = CursorCommandLine.run() {
            exit(exitCode)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: sparkleUpdater.updaterController.updater)
            }
            CommandMenu("Language") {
                ForEach(AppLanguage.allCases) { language in
                    Button(Localized.string(language.titleKey)) {
                        languageBinding.wrappedValue = language
                    }
                    .disabled(languageBinding.wrappedValue == language)
                }
            }
        }
    }

    private var sparkleUpdater: SparkleUpdaterController {
        SparkleUpdaterController.shared
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { localization.selectedLanguage ?? inferredInitialLanguage },
            set: { newValue in
                localization.setLanguage(newValue)
                appDelegate.controller.relocalize()
            }
        )
    }

    private var inferredInitialLanguage: AppLanguage {
        Localized.inferredLanguage(from: Locale.preferredLanguages.first)
    }
}
