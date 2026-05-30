import Foundation

/// Debug-only `print()` wrapper. In Release builds the message string is
/// never even evaluated (the `@autoclosure` is only invoked inside the
/// `#if DEBUG` branch), so there's zero runtime cost in shipping binaries.
///
/// Use this everywhere instead of `print(...)`. The whole codebase was
/// migrated in one pass before the first App Store submission so the
/// shipped binary doesn't spam Console.app or pay the formatting cost.
@inlinable
func dprint(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
