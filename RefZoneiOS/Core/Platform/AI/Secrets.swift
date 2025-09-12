import Foundation

enum Secrets {
    /// Returns the OpenAI API key.
    /// Priority: Info.plist key (Debug only injection) → Debug env var → nil
    static var openAIKey: String? {
        // Prefer value injected via Info.plist (Debug builds set INFOPLIST_KEY_OPENAI_API_KEY)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           key.isEmpty == false {
            return key
        }

        #if DEBUG
        // Fallback to environment variable for local dev/CI
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], env.isEmpty == false {
            return env
        }
        #endif

        return nil
    }
}
