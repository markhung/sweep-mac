import SwiftUI
import AppKit

// MARK: - 随包资源加载

enum Resources {
    /// 从 .app 的 Resources 目录直接读文件，不依赖 Asset Catalog
    static func image(_ name: String, ext: String = "png") -> NSImage? {
        guard let base = Bundle.main.resourceURL else { return nil }
        let url = base.appendingPathComponent("assets/\(name).\(ext)")
        return NSImage(contentsOf: url)
    }
}

// MARK: - SWEEP 字标

/// 自设计的几何圆体中线的六个字形（S / W 两段圆弧 / E / E / P），
/// viewBox 为 505 × 100，与图标用的是同一份坐标。
struct SweepGlyphLines: Shape {

    private static let k: CGFloat = 0.552_284_749_8

    func path(in rect: CGRect) -> Path {
        // SVG 默认 preserveAspectRatio="xMidYMid meet"：等比缩放并居中
        let s = min(rect.width / 505, rect.height / 100)
        let dx = rect.minX + (rect.width - 505 * s) / 2
        let dy = rect.minY + (rect.height - 100 * s) / 2
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x * s, y: dy + y * s) }

        var path = Path()

        // S —— 两个反向贝塞尔勾
        path.move(to: P(67, 32))
        path.addCurve(to: P(17, 35), control1: P(67, 18), control2: P(17, 18))
        path.addCurve(to: P(67, 62), control1: P(17, 51), control2: P(67, 45))
        path.addCurve(to: P(17, 64), control1: P(67, 79), control2: P(17, 79))

        // W —— 两条 U 形弧（比折线软萌），底部 overshoot 到 y=80
        appendU(&path, from: P(115, 22), bottom: P(115, 60), upper: P(155, 22), r: 20 * s)
        appendU(&path, from: P(155, 22), bottom: P(155, 60), upper: P(195, 22), r: 20 * s)

        // E E —— 主干 + 三横（中横略短）
        for x in [CGFloat(243), CGFloat(337)] {
            path.move(to: P(x, 22)); path.addLine(to: P(x, 78))
            path.move(to: P(x, 22)); path.addLine(to: P(x + 46, 22))
            path.move(to: P(x, 50)); path.addLine(to: P(x + 36, 50))
            path.move(to: P(x, 78)); path.addLine(to: P(x + 46, 78))
        }

        // P —— 主干 + 右侧半圆碗
        path.move(to: P(431, 78))
        path.addLine(to: P(431, 22))
        path.addLine(to: P(469, 22))
        appendSemicircle(&path, a: P(469, 22), b: P(469, 60), bulgeSign: -1, k: Self.k)
        path.addLine(to: P(431, 60))

        return path
    }

    /// 从 upper 竖直下到 bottom，再走一个向下鼓的半圆回到 upper
    private func appendU(_ path: inout Path,
                         from upper: CGPoint, bottom: CGPoint, upper right: CGPoint,
                         r: CGFloat) {
        path.move(to: upper)
        path.addLine(to: bottom)
        appendSemicircle(&path, a: bottom, b: CGPoint(x: right.x, y: bottom.y), bulgeSign: 1, k: Self.k)
        path.addLine(to: right)
    }

    /// 半圆：从 a 到 b，向 bulgeSign 侧的法线方向鼓出。
    /// 用两段三次贝塞尔精确逼近，避免各家 API 的 clockwise 语义差异。
    private func appendSemicircle(_ path: inout Path,
                                 a: CGPoint, b: CGPoint,
                                 bulgeSign: CGFloat, k: CGFloat) {
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let len = hypot(b.x - a.x, b.y - a.y)
        guard len > 0 else { return }
        let r = len / 2
        let dir = CGPoint(x: (b.x - a.x) / len, y: (b.y - a.y) / len)
        let n = CGPoint(x: -dir.y * bulgeSign, y: dir.x * bulgeSign)
        let apex = CGPoint(x: mid.x + r * n.x, y: mid.y + r * n.y)
        let kr = k * r

        path.addCurve(to: apex,
                      control1: CGPoint(x: a.x + kr * n.x, y: a.y + kr * n.y),
                      control2: CGPoint(x: apex.x - kr * dir.x, y: apex.y - kr * dir.y))
        path.addCurve(to: b,
                      control1: CGPoint(x: apex.x + kr * dir.x, y: apex.y + kr * dir.y),
                      control2: CGPoint(x: b.x + kr * n.x, y: b.y + kr * n.y))
    }
}

/// SWEEP 字标：猫系主题用镂空粉渐变，极简科技用单色实心。
struct BrandMark: View {
    var width: CGFloat = 74
    var height: CGFloat = 16.2
    @ObservedObject var themeManager: ThemeManager

    private var theme: Theme { themeManager.currentTheme }
    private var scale: CGFloat { min(width / 505, height / 100) }
    private var outerLine: CGFloat { 34 * scale }
    private var innerLine: CGFloat { 20 * scale }

    var body: some View {
        ZStack {
            switch theme.brand {
            case .anime:
                animeBrand
            case .minimal:
                minimalBrand
            }
        }
        .frame(width: width, height: height)
    }

    private var animeBrand: some View {
        ZStack {
            SweepGlyphLines()
                .stroke(style: StrokeStyle(lineWidth: outerLine, lineCap: .round, lineJoin: .round))
                .foregroundStyle(theme.colors.brand)

            SweepGlyphLines()
                .stroke(style: StrokeStyle(lineWidth: innerLine, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .shadow(color: .white.opacity(0.85), radius: 1, x: 0, y: 0)
        .shadow(color: Color(hex: 0xF2549B, alpha: 0.38), radius: 1.2, x: 0, y: 1.6)
    }

    private var minimalBrand: some View {
        SweepGlyphLines()
            .stroke(style: StrokeStyle(lineWidth: outerLine, lineCap: .round, lineJoin: .round))
            .foregroundStyle(theme.colors.brand)
    }
}

// MARK: - 进度环

/// 从 12 点开始、顺时针推进的圆弧。
/// 先把 Circle 的几何旋转到 12 点起，再交给外层描边——
/// 这样渐变的走向仍然按视图边界来算，和原型一致。
struct RingArc: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        let clamped = max(0, min(progress, 1))
        guard clamped > 0 else { return Path() }
        let base = Circle().path(in: rect).trimmedPath(from: 0, to: clamped)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        return base.applying(
            CGAffineTransform(translationX: c.x, y: c.y)
                .rotated(by: -.pi / 2)
                .translatedBy(x: -c.x, y: -c.y)
        )
    }
}

/// 四角星（进度头部 / 结果页点缀）
struct SparkleShape: Shape {
    /// 腰身收窄程度：越小越尖
    var waist: CGFloat = 0.22

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        func tip(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: c.x + rx * dx, y: c.y + ry * dy) }
        func ctrl(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: c.x + rx * dx * waist, y: c.y + ry * dy * waist)
        }

        var p = Path()
        p.move(to: tip(0, -1))
        p.addQuadCurve(to: tip(1, 0), control: ctrl(1, -1))
        p.addQuadCurve(to: tip(0, 1), control: ctrl(1, 1))
        p.addQuadCurve(to: tip(-1, 0), control: ctrl(-1, 1))
        p.addQuadCurve(to: tip(0, -1), control: ctrl(-1, -1))
        p.closeSubpath()
        return p
    }
}
