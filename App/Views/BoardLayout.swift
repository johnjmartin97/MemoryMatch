import CoreGraphics

/// Where the board and its cards sit. Pure arithmetic, no view involved.
enum BoardLayout {
    /// The grid is 4 x 4, so three gaps sit between four cards on a side.
    static let columns = 4
    static let rows = 4

    /// The side of one card on a board of the given side.
    static func cardSide(boardSide: CGFloat) -> CGFloat {
        let gaps = Metrics.cardGap * CGFloat(columns - 1)
        let side = (boardSide - gaps) / CGFloat(columns)
        return max(side, Metrics.minimumCardSide)
    }

    /// The board is square, inset from the screen edges on both sides, and
    /// never taller than the space it has.
    static func boardSize(
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> CGSize {
        let side = min(
            availableWidth - Metrics.boardInset * 2,
            availableHeight
        )
        return CGSize(width: side, height: side)
    }
}
