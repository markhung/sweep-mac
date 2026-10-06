import Foundation

/// Mole 的英文输出 → 中文。
///
/// 两段式：先用一小张精确表覆盖已确认原型里出现过的文案，
/// 再用「尾词规则」处理其余几百条（`X cache` → `X 缓存`），
/// 规则不命中就原样显示英文——宁可露出英文，也不要翻错。
enum MoleText {

    // MARK: - 模块名

    private static let sections: [String: String] = [
        "User essentials": "用户基础项",
        "App caches": "应用缓存",
        "Browsers": "浏览器",
        "Cloud & Office": "云服务与办公",
        "Developer tools": "开发者工具",
        "Apps & utilities": "应用与实用工具",
        "Virtualization": "虚拟化",
        "Application Support": "应用支持文件",
        "App leftovers": "应用残留",
        "Apple Silicon updates": "Apple 芯片更新",
        "Device backups & firmware": "设备备份与固件",
        "Time Machine": "时间机器",
        "Large files": "大文件",
        "Project artifacts": "项目产物",
        // 以下为兜底覆盖，避免版本差异时露英文
        "System caches": "系统缓存",
        "System": "系统",
        "Trash": "废纸篓",
        "Downloads": "下载目录",
        "Mail downloads": "邮件附件",
        "iOS backups": "iOS 备份",
        "Xcode": "Xcode",
        "Simulators": "模拟器",
        "Homebrew": "Homebrew",
        "Docker": "Docker",
        "Logs": "日志",
    ]

    static func section(_ en: String) -> String {
        let key = en.trimmingCharacters(in: .whitespaces)
        return sections[key] ?? key
    }

    // MARK: - 条目名

    /// 已确认原型里出现过的文案，逐条钉死
    private static let itemOverrides: [String: String] = [
        "User app cache": "用户应用缓存",
        "User app logs": "用户应用日志",
        "Geod temp files": "Geod 临时文件",
        "Maps geo tile cache": "地图地理瓦片缓存",
        "Chrome crash reports": "Chrome 崩溃报告",
        "GoogleUpdater CRX cache": "GoogleUpdater 更新缓存",
        "Dia Application Support cache": "Dia 应用支持缓存",
        "npm cache": "npm 缓存",
        "npm logs": "npm 日志",
        "Corepack cache": "Corepack 缓存",
        "pip cache": "pip 缓存",
        "uv cache": "uv 缓存",
        "Oh My Zsh cache": "Oh My Zsh 缓存",
        "Project caches": "项目构建缓存",
        "Clang module cache": "Clang 模块缓存",
        "Codex runtimes": "Codex 运行时",
        "Zsh completion cache": "Zsh 补全缓存",
        "WeType dict update cache": "WeType 词典更新缓存",
        "Application Support logs/caches": "应用支持日志与缓存",
        "Build artifacts": "构建产物",
        "Nothing to clean": "无需清理",
    ]

    /// 尾词规则：命中即把尾词换成中文，前面的产品名保持原样
    private static let tailRules: [(suffix: String, cn: String)] = [
        // 长尾优先，避免 "module cache" 被 "cache" 抢先匹配
        ("application support cache", "应用支持缓存"),
        ("application support", "应用支持文件"),
        ("geo tile cache", "地理瓦片缓存"),
        ("module cache", "模块缓存"),
        ("dict update cache", "词典更新缓存"),
        ("completion cache", "补全缓存"),
        ("crash reports", "崩溃报告"),
        ("crx cache", "更新缓存"),
        ("font cache", "字体缓存"),
        ("image cache", "图片缓存"),
        ("media cache files", "媒体缓存文件"),
        ("media cache", "媒体缓存"),
        ("thumbnails", "缩略图缓存"),
        ("previews", "预览缓存"),
        ("temp files", "临时文件"),
        ("temporary files", "临时文件"),
        ("log files", "日志文件"),
        ("cache files", "缓存文件"),
        ("support files", "支持文件"),
        ("leftovers", "残留文件"),
        ("sessions", "会话数据"),
        ("history", "历史记录"),
        ("archives", "归档文件"),
        ("artifacts", "构建产物"),
        ("firmware", "固件"),
        ("updates", "更新包"),
        ("reports", "报告"),
        ("runtimes", "运行时"),
        ("runtime", "运行时"),
        ("backups", "备份"),
        ("backup", "备份"),
        ("downloads", "下载内容"),
        ("databases", "数据库"),
        ("database", "数据库"),
        ("index", "索引"),
        ("state", "状态文件"),
        ("caches", "缓存"),
        ("cache", "缓存"),
        ("logs", "日志"),
        ("log", "日志"),
        ("temp", "临时文件"),
    ]

    static func item(_ en: String) -> String {
        let raw = en.trimmingCharacters(in: .whitespaces)
        if let hit = itemOverrides[raw] { return hit }

        let lower = raw.lowercased()
        for rule in tailRules {
            guard lower.hasSuffix(rule.suffix) else { continue }
            let head = String(raw.dropLast(rule.suffix.count))
                .trimmingCharacters(in: .whitespaces)
            // 尾词前没有限定词（整名就是尾词）时，直接用中文
            if head.isEmpty { return rule.cn }
            // 尾部如果还挂着斜杠或括号，交给兜底，避免拼出怪句子
            guard !head.hasSuffix("/"), !head.hasSuffix("("), !head.hasSuffix("-") else { break }
            return head + " " + rule.cn
        }
        return raw
    }

    // MARK: - 跳过 / 状态说明

    private static let statusPhrases: [String: String] = [
        "would clean": "可清理",
        "nothing to clean": "无需清理",
        "manual review": "需手动确认",
        "scan skipped": "已跳过扫描",
        "needs purge": "需用 purge 命令",
        "in use": "正在使用中",
        "permission denied": "权限不足",
        "protected": "受保护",
        "whitelisted": "白名单已保护",
        "not found": "未找到",
        "timed out": "检查超时",
        "timeout": "检查超时",
    ]

    /// 处理 `◎ Dia Application Support cache · skipped (Dia running)` 里括号内的原因。
    /// 原因本身可能是多段（`scan skipped · mo purge`），逐段翻译后用顿号连起来。
    static func reason(_ en: String) -> String {
        let parts = en
            .components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return en }
        return parts.map(translateReason).joined(separator: "，")
    }

    private static func translateReason(_ raw: String) -> String {
        let lower = raw.lowercased()

        // "3 slow/incomplete root scans"
        let digits = raw.prefix { $0.isNumber }
        if !digits.isEmpty, lower.contains("slow/incomplete root scan") {  // 单复数都算
            return "\(digits) 个根目录扫描过慢"
        }
        // "Dia running" / "Chrome running"
        if lower.hasSuffix(" running") {
            let app = String(raw.dropLast(" running".count))
            return "\(app) 正在运行"
        }
        if lower.contains("purge") { return "需用 purge 命令" }

        for (en0, cn) in statusPhrases where lower.contains(en0) {
            return cn
        }
        return raw
    }

    // MARK: - 俏皮话

    /// 进入模块时说的那句话（键为中文模块名）
    static let quips: [String: String] = [
        "用户基础项": "先从缓存开始扫～",
        "应用缓存": "这边有点灰，扫掉！",
        "浏览器": "浏览器角落也看看～",
        "云服务与办公": "嗯…这里挺干净的",
        "开发者工具": "重头戏来了，加油！",
        "应用与实用工具": "小角落也不放过～",
        "虚拟化": "翻一翻，没东西～",
        "应用支持文件": "检查一下…干净！",
        "应用残留": "找找有没有留下的垃圾～",
        "Apple 芯片更新": "顺手清一下～",
        "设备备份与固件": "这里不乱，放心",
        "时间机器": "备份区不能乱动哦",
        "大文件": "巡视一圈…没发现～",
        "项目产物": "这个要你自己决定啦",
    ]

    static func quip(for sectionCN: String) -> String {
        quips[sectionCN] ?? "继续扫一扫～"
    }
}
