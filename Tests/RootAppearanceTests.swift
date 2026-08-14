import CoreGraphics
import SwiftUI
import XCTest
@testable import MemoryMatch

/// What the root screen actually draws in each appearance.
///
/// These tests render `ContentView` to a bitmap and read the pixels back, so
/// they see what a person launching the app sees. Checking a palette helper in
/// isolation would not: the palette can hold every dark token and still never
/// be asked for one.
@MainActor
final class RootAppearanceTests: XCTestCase {

    // MARK: - Rendering

    private static let canvas = CGSize(width: 375, height: 812)

    /// Renders the root view at iPhone size in the given appearance.
    private func renderRoot(_ scheme: ColorScheme) throws -> CGImage {
        let view = ContentView()
            .frame(width: Self.canvas.width, height: Self.canvas.height)
            .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(Self.canvas)

        return try XCTUnwrap(
            renderer.cgImage,
            "the root view rendered to a bitmap"
        )
    }

    // MARK: - Pixels

    private struct RGB: Equatable {
        var red: Int, green: Int, blue: Int

        init(red: Int, green: Int, blue: Int) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(hex: UInt32) {
            red = Int((hex >> 16) & 0xFF)
            green = Int((hex >> 8) & 0xFF)
            blue = Int(hex & 0xFF)
        }

        /// Largest per-channel difference, in 0...255.
        func distance(to other: RGB) -> Int {
            max(
                abs(red - other.red),
                max(abs(green - other.green), abs(blue - other.blue))
            )
        }

        var description: String {
            String(format: "#%02X%02X%02X", red, green, blue)
        }
    }

    /// Every pixel of the image as straight 8-bit sRGB, row by row.
    private func pixels(of image: CGImage) throws -> (
        values: [RGB], width: Int, height: Int
    ) {
        let width = image.width
        let height = image.height
        var raw = [UInt8](repeating: 0, count: width * height * 4)

        let context = try XCTUnwrap(
            CGContext(
                data: &raw,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ),
            "a bitmap context to read the render back from"
        )
        // Opaque white underneath, so any unpainted area reads as white
        // rather than as a colour the palette also happens to contain.
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )

        var values: [RGB] = []
        values.reserveCapacity(width * height)
        for index in stride(from: 0, to: raw.count, by: 4) {
            values.append(
                RGB(
                    red: Int(raw[index]),
                    green: Int(raw[index + 1]),
                    blue: Int(raw[index + 2])
                )
            )
        }
        return (values, width, height)
    }

    private func pixel(
        _ grid: (values: [RGB], width: Int, height: Int),
        x: Int,
        y: Int
    ) -> RGB {
        grid.values[y * grid.width + x]
    }

    /// How close the nearest pixel in the image comes to `colour`.
    private func closestDistance(
        _ grid: (values: [RGB], width: Int, height: Int),
        to colour: RGB
    ) -> Int {
        grid.values.reduce(255) { best, pixel in
            min(best, pixel.distance(to: colour))
        }
    }

    // MARK: - Background

    /// In Dark, the screen behind the board is the dark background gradient
    /// from `ART.md` (#1A1F26 down to #0F1318) — not the cream light one the
    /// cards are drawn against.
    func testDarkLaunchDrawsTheDarkBackgroundGradient() throws {
        let grid = try pixels(of: renderRoot(.dark))

        let topLeft = pixel(grid, x: 2, y: 2)
        let bottomLeft = pixel(grid, x: 2, y: grid.height - 3)

        let expectedTop = RGB(hex: 0x1A1F26)
        let expectedBottom = RGB(hex: 0x0F1318)
        let lightTop = RGB(hex: 0xFDF6EC)
        let lightBottom = RGB(hex: 0xF0E2D2)

        XCTAssertLessThanOrEqual(
            topLeft.distance(to: expectedTop),
            4,
            """
            top of the dark screen is #1A1F26, got \(topLeft.description) \
            (light background top is \(lightTop.description))
            """
        )
        XCTAssertLessThanOrEqual(
            bottomLeft.distance(to: expectedBottom),
            4,
            """
            bottom of the dark screen is #0F1318, got \
            \(bottomLeft.description) (light background bottom is \
            \(lightBottom.description))
            """
        )
    }

    /// Light is unchanged: the cream gradient, top to bottom.
    func testLightLaunchDrawsTheLightBackgroundGradient() throws {
        let grid = try pixels(of: renderRoot(.light))

        let topLeft = pixel(grid, x: 2, y: 2)
        let bottomLeft = pixel(grid, x: 2, y: grid.height - 3)

        XCTAssertLessThanOrEqual(
            topLeft.distance(to: RGB(hex: 0xFDF6EC)),
            4,
            "top of the light screen is #FDF6EC, got \(topLeft.description)"
        )
        XCTAssertLessThanOrEqual(
            bottomLeft.distance(to: RGB(hex: 0xF0E2D2)),
            4,
            """
            bottom of the light screen is #F0E2D2, got \
            \(bottomLeft.description)
            """
        )
    }

    // MARK: - Title

    /// In Dark the title is drawn in the dark muted text token (#98A1AC).
    /// The light token (#6E7780) is much darker; if it were used, no pixel on
    /// screen would come near #98A1AC.
    func testDarkLaunchDrawsTheTitleInTheDarkMutedTextColour() throws {
        let grid = try pixels(of: renderRoot(.dark))

        let darkMuted = RGB(hex: 0x98A1AC)
        let lightMuted = RGB(hex: 0x6E7780)
        let nearest = closestDistance(grid, to: darkMuted)

        XCTAssertLessThanOrEqual(
            nearest,
            8,
            """
            the dark screen paints the title in #98A1AC; nearest pixel was \
            \(nearest) off. Drawing it in the light token \
            \(lightMuted.description) leaves nothing this close.
            """
        )
    }

    /// In Light the title is drawn in the light muted text token (#6E7780).
    func testLightLaunchDrawsTheTitleInTheLightMutedTextColour() throws {
        let grid = try pixels(of: renderRoot(.light))

        let nearest = closestDistance(grid, to: RGB(hex: 0x6E7780))
        XCTAssertLessThanOrEqual(
            nearest,
            8,
            """
            the light screen paints the title in #6E7780; nearest pixel was \
            \(nearest) off
            """
        )
    }

    // MARK: - Cards

    /// The board and the screen agree. In Dark the card backs are the dark
    /// Primary (#3E8C9E) — they already were — and now they sit on the dark
    /// background rather than on a cream wash.
    func testDarkLaunchDrawsCardBacksOnTheDarkBackground() throws {
        let grid = try pixels(of: renderRoot(.dark))

        XCTAssertLessThanOrEqual(
            closestDistance(grid, to: RGB(hex: 0x3E8C9E)),
            4,
            "the dark screen shows dark-teal card backs (#3E8C9E)"
        )
        // Nothing on the dark screen may be painted in a light background
        // token: that mix is the broken state this test exists to catch.
        XCTAssertGreaterThan(
            closestDistance(grid, to: RGB(hex: 0xFDF6EC)),
            8,
            "no part of the dark screen is painted in the light cream #FDF6EC"
        )
    }
}
