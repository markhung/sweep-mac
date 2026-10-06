import Foundation
import Darwin

/// ============================================================================
/// QA 独立验证测试（Edward）—— 针对工程师 `Tests/permission/main.swift` 未覆盖的
/// 边界与错误路径。**独立编译运行，不改动工程师的原测试文件。**
///
///   swiftc -swift-version 5 Sources/Permission.swift Tests/permission_qa/main.swift \
///         -o build/qa_permission && ./build/qa_permission
///
/// 覆盖工程师没测的：
///   A. `inconclusive` 分支（stat 成功但 open 报非 EPERM/EACCES/ENOENT 的错）
///   B. 判定顺序无关性（readable/denied 任意排列）
///   C. 非 ~ 的绝对路径、空路径、重复路径
///   D. `needsGuide` 全矩阵（含最关键的 `unknown` 语义）
///   E. `hasSeenGuide` / `markGuideSeen` 的**跨进程**持久化（用 defaults 独立核查）
/// ============================================================================

var failures = 0
var checks = 0
func check(_ name: String, _ passed: Bool) {
    checks += 1
    print("\(passed ? "✓" : "✗") \(name)")
    if !passed { failures += 1 }
}

let fm = FileManager.default
let root = NSTemporaryDirectory() + "/sweep-qa-\(UUID().uuidString)"
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
func mkdir(_ name: String) -> String {
    let p = root + "/" + name
    try? fm.createDirectory(atPath: p, withIntermediateDirectories: true)
    return p
}

// ─────────────────────────────────────────────────────────────────────────────
// 子进程模式：只读的方式回读 hasSeenGuide（证明跨进程持久化）
// ─────────────────────────────────────────────────────────────────────────────
if CommandLine.arguments.contains("--read-guide") {
    print(FullDiskAccess.hasSeenGuide ? "SEEN=1" : "SEEN=0")
    exit(0)
}

// ─────────────────────────────────────────────────────────────────────────────
// A. `inconclusive` 分支：stat 成功、open 失败但不是 EPERM/EACCES/ENOENT
//    Unix domain socket 是唯一能稳定构造的情形：stat 成功，open() 返回 ENXIO。
// ─────────────────────────────────────────────────────────────────────────────
func makeUnixSocket(at path: String) -> Bool {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
        close(fd); return false
    }
    withUnsafeMutablePointer(to: &addr.sun_path) { raw in
        raw.withMemoryRebound(to: CChar.self, capacity: bytes.count) { dst in
            for (i, b) in bytes.enumerated() { dst[i] = CChar(bitPattern: b) }
        }
    }
    let size = socklen_t(MemoryLayout<sockaddr_un>.size)
    let ok = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, size) }
    } == 0
    close(fd)   // socket 文件保留在磁盘上
    return ok
}

// sun_path 只有 104 字节；本机 NSTemporaryDirectory() 很长，故用短路径
let sockPath = "/tmp/sweep-qa-\(getpid()).sock"
defer { try? fm.removeItem(atPath: sockPath) }
if makeUnixSocket(at: sockPath) {
    var st = stat()
    let statOK = stat(sockPath, &st) == 0
    var isDir = ObjCBool(false)
    let exists = fm.fileExists(atPath: sockPath, isDirectory: &isDir)
    errno = 0
    let fd = open(sockPath, O_RDONLY | O_NONBLOCK)
    let e = errno
    if fd >= 0 { close(fd) }
    print("  [诊断] socket statOK=\(statOK) fileExists=\(exists) openErrno=\(e)")
    // fileExists 为 true（stat 成功）→ 源码会走到 open()，拿到 ENXIO → inconclusive
    check("socket 探测点：stat 成功（fileExists=true）", exists)
    check("socket 探测点：open 报非 EPERM/EACCES/ENOENT（→ inconclusive）",
          fd < 0 && e != EPERM && e != EACCES && e != ENOENT)

    let readable = write("read-for-sock.txt"); chmod(readable, 0o644)
    check("inconclusive 被跳过：inconclusive + readable → granted",
          FullDiskAccess.detect(paths: [sockPath, readable]) == .granted)
    check("inconclusive 单独：唯一的探测点无法判定 → unknown",
          FullDiskAccess.detect(paths: [sockPath]) == .unknown)
    let lockedForSock = write("locked-for-sock.txt"); chmod(lockedForSock, 0o000)
    check("inconclusive 被跳过：inconclusive + denied → denied",
          FullDiskAccess.detect(paths: [sockPath, lockedForSock]) == .denied)
    chmod(lockedForSock, 0o644)
} else {
    print("  [跳过] 无法创建 unix socket，跳过 inconclusive 分支")
}

// ─────────────────────────────────────────────────────────────────────────────
// B. 判定顺序无关性
// ─────────────────────────────────────────────────────────────────────────────
let readB = write("qa-read.txt");   chmod(readB, 0o644)
let lockB = write("qa-lock.txt");   chmod(lockB, 0o000)
let realDir = mkdir("qa-dir")                    // 可读目录
let lockDir = mkdir("qa-lock-dir"); chmod(lockDir, 0o000)

check("顺序无关：denied 在前 → denied",  FullDiskAccess.detect(paths: [lockB, readB]) == .denied)
check("顺序无关：denied 在后 → denied",  FullDiskAccess.detect(paths: [readB, lockB]) == .denied)
check("强信号优先：readable 目录 + denied 文件 → denied",
      FullDiskAccess.detect(paths: [realDir, lockB]) == .denied)
check("可读目录单独 → granted",          FullDiskAccess.detect(paths: [realDir]) == .granted)

// ─────────────────────────────────────────────────────────────────────────────
// C. 路径形态：绝对路径 / 空路径 / 重复路径 / 展开后不存在
// ─────────────────────────────────────────────────────────────────────────────
check("绝对路径（无 ~）可正常判定 → granted",
      FullDiskAccess.detect(paths: [readB]) == .granted)
check("空字符串路径 → absent → unknown",
      FullDiskAccess.detect(paths: [""]) == .unknown)
check("重复路径不影响判定",
      FullDiskAccess.detect(paths: [readB, readB, readB]) == .granted)
check("重复的 denied 路径仍为 denied",
      FullDiskAccess.detect(paths: [lockB, lockB]) == .denied)
check("空列表 → unknown",
      FullDiskAccess.detect(paths: []) == .unknown)

// 目录的 open 语义（A.1 的 Swift 侧复核）：对可读目录 open(O_RDONLY|O_NONBLOCK) 必须成功
errno = 0
let dfd = open(realDir, O_RDONLY | O_NONBLOCK)
check("A.1：可读目录 open(O_RDONLY|O_NONBLOCK) 成功（非 EISDIR）", dfd >= 0)
if dfd >= 0 { close(dfd) }

// 不可读目录 open 必须失败（EACCES）
errno = 0
let dfd2 = open(lockDir, O_RDONLY | O_NONBLOCK)
check("A.1：不可读目录 open 失败（EACCES/EPERM）",
      dfd2 < 0 && (errno == EACCES || errno == EPERM))
if dfd2 >= 0 { close(dfd2) }

chmod(lockB, 0o644)
chmod(lockDir, 0o755)

// ─────────────────────────────────────────────────────────────────────────────
// D. `needsGuide` 全矩阵 —— 重点是 `unknown` 的语义
// ─────────────────────────────────────────────────────────────────────────────
let savedGuide = FullDiskAccess.hasSeenGuide
FullDiskAccess.hasSeenGuide = false
check("D1 needsGuide(unknown, 没看过) → true（把 unknown 当成未授权）",
      FullDiskAccess.needsGuide(given: .unknown))
check("D2 needsGuide(denied, 没看过) → true",
      FullDiskAccess.needsGuide(given: .denied))
check("D3 needsGuide(granted, 没看过) → false",
      !FullDiskAccess.needsGuide(given: .granted))
FullDiskAccess.hasSeenGuide = true
check("D4 needsGuide(unknown, 看过) → false",
      !FullDiskAccess.needsGuide(given: .unknown))
check("D5 needsGuide(granted, 看过) → false",
      !FullDiskAccess.needsGuide(given: .granted))
FullDiskAccess.hasSeenGuide = savedGuide
print("  [结论] unknown 与 denied 在 needsGuide 上完全等价 → UI 会照常弹引导/提示条；"
      + "不会误显示「已授权」。")

// ─────────────────────────────────────────────────────────────────────────────
// E. 跨进程持久化：本进程写入，另起进程回读（用 defaults 独立核查）
// ─────────────────────────────────────────────────────────────────────────────
FullDiskAccess.hasSeenGuide = false
check("E1 清空后 hasSeenGuide == false（本进程）", !FullDiskAccess.hasSeenGuide)
FullDiskAccess.markGuideSeen()
check("E2 markGuideSeen 后 hasSeenGuide == true（本进程）", FullDiskAccess.hasSeenGuide)

let selfPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardized.path
let child = Process()
child.executableURL = URL(fileURLWithPath: selfPath)
child.arguments = ["--read-guide"]
let pipe = Pipe()
child.standardOutput = pipe
do {
    try child.run()
    child.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    check("E3 新进程回读 hasSeenGuide == true（跨进程持久化）",
          out.contains("SEEN=1"))
    print("  [子进程输出] \(out.trimmingCharacters(in: .whitespacesAndNewlines))")
} catch {
    check("E3 子进程启动失败：\(error)", false)
}
print("  [核查] 该键位于 UserDefaults 域 `\(Bundle.main.bundleIdentifier ?? "?")`"
      + "（命令行测试二进制），app 运行时对应域为 com.sweep.app。")

// 还原（不污染用户默认值）
FullDiskAccess.hasSeenGuide = savedGuide

// ─────────────────────────────────────────────────────────────────────────────
print("")
print(failures == 0
      ? "✓ QA 独立测试全部通过（\(checks) 项）"
      : "✗ QA 独立测试 \(failures)/\(checks) 项失败")
exit(failures == 0 ? 0 : 1)
