import Foundation

/// 解析器回归测试（不依赖 GUI，可直接编译运行）：
///     swiftc Sources/Models.swift Sources/MoleText.swift Sources/StreamParser.swift \
///           Tests/parse_test.swift -o build/parse_test && ./build/parse_test <mole 输出文件>
///
/// 传文件路径则解析该文件；不传则跑内置用例。

var parser = MoleStreamParser()

func describe(_ event: EngineEvent) -> String {
    switch event {
    case let .diskInfo(text, bytes):
        return "DISK      \(text)   [\(bytes.map(String.init) ?? "nil")]"
    case let .moduleStarted(name):
        return "SECTION   \(MoleText.section(name))"
    case let .entry(e):
        let kind: String
        switch e.kind {
        case .section: kind = "SEC "
        case .item:    kind = "ITEM"
        case .skip:    kind = "SKIP"
        case .manual:  kind = "MAN "
        case .empty:   kind = "EMPT"
        case .info:    kind = "INFO"
        case .error:   kind = "ERR "
        }
        let size = e.size.map { "  size=\($0)" } ?? ""
        let note = e.note.map { "  note=\($0)" } ?? ""
        return "\(kind)      \(e.text)\(size)\(note)"
    case let .freeSpaceAfter(bytes):
        return "FREE-AFTR \(SizeFormat.human(bytes))"
    case let .info(text):
        return "INFO      \(text)"
    }
}

// MARK: - 内置用例

let fixtures = """
➤ User essentials
  → User app cache · 6 items, 84.2MB dry
  → User app logs · 4 items, 16KB dry

➤ Browsers
  ◎ Dia Application Support cache · skipped (Dia running)

➤ Cloud & Office
  ✓ Nothing to clean

➤ Developer tools
  → npm cache · would clean
  → npm logs · 3 items, 3KB dry
  ⊙ Codex runtimes · manual review

▶ 无用行：Whitelist
✓ Whitelist: 19 core patterns active

⚙ Apple Silicon | Free space: 177.40GB
Potential space: 428.8MB | Items: 49 | Categories: 6
"""

let live = """
Clean Your Mac

Cleanup complete
Tracked cleanup: 1.24GB | Items cleaned: 18
Free space: 223.5GB (+1.24GB)
"""

// MARK: - 主流程

func collect(_ text: String, chunk: Int?) -> (events: [EngineEvent], summary: EngineSummary) {
    parser.reset()
    var events: [EngineEvent] = []
    if let chunk {
        // 模拟管道分片：任意位置切断都不该影响结果
        var idx = text.startIndex
        while idx < text.endIndex {
            let end = text.index(idx, offsetBy: chunk, limitedBy: text.endIndex) ?? text.endIndex
            events += parser.feed(String(text[idx..<end]))
            idx = end
        }
    } else {
        events = parser.feed(text)
    }
    events += parser.flush()
    return (events, parser.summary)
}

func run(_ name: String, _ text: String) {
    parser.reset()
    print("\n=== \(name) ===")
    var events = parser.feed(text)
    events += parser.flush()
    for e in events { print(describe(e)) }
    let s = parser.summary
    print("SUMMARY   reclaimed=\(SizeFormat.human(s.reclaimedBytes)) "
          + "items=\(s.itemsCleaned) cats=\(s.categories) "
          + "freeAfter=\(s.freeAfterBytes.map(SizeFormat.human) ?? "nil")")
}

/// 整段喂入与逐块喂入必须完全一致——这是流式解析最容易出错的地方。
/// 注意 LogEntry 的 == 是「同一实例」语义（id 每次新生成），
/// 所以这里按渲染后的文本比较，才是真正的值比较。
func verifyChunking(_ name: String, _ text: String) {
    let whole = collect(text, chunk: nil)
    let wholeText = whole.events.map(describe)
    var ok = true
    for chunk in [1, 3, 7, 64, 997] {
        let parts = collect(text, chunk: chunk)
        let partsText = parts.events.map(describe)
        if partsText != wholeText || parts.summary != whole.summary {
            ok = false
            print("✗ \(name) 分片 \(chunk) 字节结果不一致："
                  + "整段 \(wholeText.count) 事件 / 分片 \(partsText.count) 事件")
            if partsText != wholeText {
                for (a, b) in zip(wholeText, partsText) where a != b {
                    print("   整段: \(a)\n   分片: \(b)")
                    break
                }
            }
            if parts.summary != whole.summary {
                print("   汇总: \(whole.summary) vs \(parts.summary)")
            }
        }
    }
    print(ok ? "✓ \(name) 分片一致性通过（1/3/7/64/997 字节，\(wholeText.count) 事件）"
             : "✗ \(name) 分片一致性失败")
}

let args = Array(CommandLine.arguments.dropFirst())
if let path = args.first {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("读不到文件：\(path)"); exit(1)
    }
    run(path, text)
    verifyChunking(path, text)
} else {
    run("内置用例（预览模式）", fixtures)
    run("内置用例（真实模式汇总）", live)
    verifyChunking("内置用例（预览模式）", fixtures)
    verifyChunking("内置用例（真实模式汇总）", live)
}
