import Foundation

enum Secrets {
  /// The iOS app no longer embeds an OpenAI API key. The assistant only needs
  /// enough client configuration to reach the authenticated Supabase proxy.
  static var assistantProxyIsConfigured: Bool {
    (try? SupabaseEnvironment.load()) != nil
  }
}
