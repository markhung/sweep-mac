import Foundation

/// 完全磁盘访问权限探测的回归测试（不依赖 GUI，可独立编译运行）：
///
///     swiftc -swift-version 5 Sources/Permission.swift Tests/permission/main.swift \
///           -o build/permission_test && ./build/permission_test
///
/// 覆盖四种判定：
/// - 探测点存在但被拒（EPERM/EACCES）→ denied
/// - 探测点全部不存在（ENOENT）→ unknown（降级）
/// - 探测点全部可读 → granted
/// - 本机真实环境（未授权）→ denied
///
/// 其中被拒场景用临时目录里 `chmod 000` 的文件 / 子目录构造，无需 root。
/// 因为 `FullDiskAccess.detect(paths:)` 的探测点可注入，所以能稳定复现。

var failures = 0
func check(_ name: String, _ passed: Bool) {
    print("\(passed ? "✓" : "✗") \(name)")
    if !passed { failures += 1 }
}

let fm = FileManager.default
let root = NSTemporaryDirectory() + "/sweep-permission-\(UUID().uuidString)"
try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
defer { try? fm.removeItem(atPath: root) }

func write(_ name: String, _ text: String = "x") -> String {
    let p = root + "/" + name
    try? text.data(using: .utf8)?.write(to: URL(fileURLWithPath: p))
    return p
}

func chmod(_ path: String, _ mode: Int) {
    try? fm.setAttributes([.posixPermissions: mode], ofItemAtPath: path)
}

// ── 1. 全部不存在 → unknown（降级：无法判定）
let missingA = root + "/nope-a"
let missingB = root + "/nope-b-\(UUID().uuidString)"
check("全部探测点不存在 → unknown",
      FullDiskAccess.detect(paths: [missingA, missingB]) == .unknown)

// ── 2. 全部可读 → granted
let readA = write("read-a.txt")
let readB = write("read-b.txt")
chmod(readA, 0o644)
chmod(readB, 0o644)
check("全部探测点可读 → granted",
      FullDiskAccess.detect(paths: [readA, readB]) == .granted)

// ── 3. 存在但被拒（EPERM/EACCES）→ denied
let lockedFile = write("locked.txt")
chmod(lockedFile, 0o000)
let lockedDir = root + "/locked-dir"
try? fm.createDirectory(atPath: lockedDir, withIntermediateDirectories: true)
chmod(lockedDir, 0o000)

check("文件存在但不可读 → denied",
      FullDiskAccess.detect(paths: [lockedFile]) == .denied)
check("目录存在但不可读 → denied",
      FullDiskAccess.detect(paths: [lockedDir]) == .denied)

// ── 4. 混合：可读 + 不可读 → denied（存在点被拒是强信号，优先于可读）
check("可读与不可读混合 → denied",
      FullDiskAccess.detect(paths: [readA, lockedFile]) == .denied)

// ── 5. 存在与不存在混合：不存在的点应被跳过，不影响判定
check("可读 + 不存在 → granted",
      FullDiskAccess.detect(paths: [readA, missingA]) == .granted)
check("不可读 + 不存在 → denied",
      FullDiskAccess.detect(paths: [lockedFile, missingB]) == .denied)

// ── 6. 真实环境（本机未授权）→ denied
let real = FullDiskAccess.detect()
print("真实环境检测结果：\(real)")
check("真实环境（本机未授权）→ denied", real == .denied)

// 清理：先把 000 权限恢复，否则 defer 里的删除会失败
chmod(lockedFile, 0o644)
chmod(lockedDir, 0o755)

print("")
if failures == 0 {
    print("✓ 全部通过")
    exit(0)
} else {
    print("✗ \(failures) 项失败")
    exit(1)
}
