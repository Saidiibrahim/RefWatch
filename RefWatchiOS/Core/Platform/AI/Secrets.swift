import Foundation

enum Secrets {
    static var openAIKey: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        #else
        return nil
        #endif
    }
}

