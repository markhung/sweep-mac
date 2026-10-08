import Foundation

/// 更新检测的纯逻辑回归测试（不依赖 GUI，可直接编译运行）：
///     swiftc Sources/UpdateService.swift Tests/update/main.swift \
///           -o build/update_test && ./build/update_test
///
/// 覆盖：版本解析/比较、更新要点提取、GitHubRelease JSON 解码。

var failures = 0
var checks = 0
func check(_ name: String, _ passed: Bool) {
    checks += 1
    print("\(passed ? "✓" : "✗") \(name)")
    if !passed { failures += 1 }
}

// MARK: - parseVersion

check("parseVersion v1.1.0", UpdateService.parseVersion("v1.1.0") == [1, 1, 0])
check("parseVersion 无前缀 1.1.0", UpdateService.parseVersion("1.1.0") == [1, 1, 0])
check("parseVersion v2.0 补齐语义（段数可不等长）", UpdateService.parseVersion("v2.0") == [2, 0])
check("parseVersion 畸形 abc → nil", UpdateService.parseVersion("abc") == nil)
check("parseVersion 空 → nil", UpdateService.parseVersion("") == nil)
check("parseVersion 空 tag v → nil", UpdateService.parseVersion("v") == nil)
check("parseVersion 空段 v..1 → nil", UpdateService.parseVersion("v..1") == nil)

// MARK: - compareVersions

check("compare 1.2.0 > 1.1.9", UpdateService.compareVersions("1.2.0", "1.1.9") == .orderedDescending)
check("compare 1.1.0 == 1.1.0.0（补 0）", UpdateService.compareVersions("1.1.0", "1.1.0.0") == .orderedSame)
check("compare 1.10.0 > 1.9.9（数值比较非字典序）",
      UpdateService.compareVersions("1.10.0", "1.9.9") == .orderedDescending)
check("compare 2.0.0 > 1.99.99", UpdateService.compareVersions("2.0.0", "1.99.99") == .orderedDescending)
check("compare 1.1.0 == v1.1.0（前缀剥离）", UpdateService.compareVersions("1.1.0", "v1.1.0") == .orderedSame)
check("compare 畸形任一侧 → nil", UpdateService.compareVersions("1.1.0", "beta") == nil)
check("compare 数组形态", UpdateService.compareVersions([1, 1, 0], [1, 1]) == .orderedSame)

// MARK: - parseNotes

let body = """
Sweep v1.2.0

- 清理引擎重写，扫描与删除整体提速约 **40%**
- 新增「重复文件」清理，按内容指纹比对，不误删
- 修复 4K 显示器下进度环边缘出现锯齿的问题
- 第四条不应该出现

普通段落文字不算要点。
"""
let notes = UpdateService.parseNotes(from: body)
check("parseNotes 取前 3 条", notes.count == 3)
check("parseNotes 剥 ** 强调", notes.first == "清理引擎重写，扫描与删除整体提速约 40%")
check("parseNotes 第 4 条被截断", !notes.contains("第四条不应该出现"))

let starNotes = UpdateService.parseNotes(from: "* 要点一\n* 要点二")
check("parseNotes 接受 * 列表", starNotes == ["要点一", "要点二"])

let longLine = "- " + String(repeating: "长", count: 100)
let truncated = UpdateService.parseNotes(from: longLine)
check("parseNotes 超长截断到 72+…", truncated.first?.count == 73 && truncated.first?.hasSuffix("…") == true)

check("parseNotes 空 body → []", UpdateService.parseNotes(from: "") == [])
check("parseNotes 纯段落 → []", UpdateService.parseNotes(from: "这是一段普通说明。") == [])
check("parseNotes 空行项跳过", UpdateService.parseNotes(from: "- **\n- 有效项") == ["有效项"])

// MARK: - GitHubRelease 解码

let json = """
{"tag_name":"v1.2.0","html_url":"https://github.com/markhung/sweep-mac/releases/tag/v1.2.0",
 "body":"- 要点","draft":false,"prerelease":false,"name":"Sweep v1.2.0","id":1}
"""
let decoded = try? JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
check("GitHubRelease 解码字段", decoded?.tagName == "v1.2.0"
      && decoded?.htmlUrl.contains("releases/tag/v1.2.0") == true
      && decoded?.body == "- 要点")

let malformed = #"{"tag_name":123,"draft":false,"prerelease":false}"#
check("GitHubRelease 字段类型错 → 解码失败不崩溃",
      (try? JSONDecoder().decode(GitHubRelease.self, from: Data(malformed.utf8))) == nil)

// MARK: - 汇总

print("── 更新检测纯逻辑：\(checks - failures)/\(checks) 通过")
if failures > 0 { exit(1) }
