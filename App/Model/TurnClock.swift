import Foundation

/// Runs a piece of work after a delay, and can be told to forget work it has
/// not run yet.
///
/// The game holds one of these instead of calling a timer directly, so a test
/// can drive time by hand instead of waiting for it. Only one piece of work is
/// ever pending: scheduling again replaces whatever was waiting.
protocol TurnClock: AnyObject {
    /// Runs `work` after `milliseconds`, replacing anything still pending.
    func schedule(after milliseconds: Int, _ work: @escaping () -> Void)

    /// Forgets pending work, so it never runs.
    func cancelPending()
}

/// The clock the running app uses: the main queue, after a real delay.
final class SystemTurnClock: TurnClock {
    private var pending: DispatchWorkItem?

    func schedule(after milliseconds: Int, _ work: @escaping () -> Void) {
        cancelPending()
        let item = DispatchWorkItem(block: work)
        pending = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds),
            execute: item
        )
    }

    func cancelPending() {
        pending?.cancel()
        pending = nil
    }
}
