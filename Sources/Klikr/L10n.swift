import Foundation

/// UI language. `system` follows macOS's preferred language when it is one of ours, else English.
enum Lang: String, CaseIterable, Identifiable {
    case system, vi, en, ja, zh, ko
    var id: String { rawValue }

    /// Each language is listed in its own name so people can find theirs whatever the UI is set to.
    var nativeName: String {
        switch self {
        case .system: L("lang.system")
        case .vi: "Tiếng Việt"
        case .en: "English"
        case .ja: "日本語"
        case .zh: "中文"
        case .ko: "한국어"
        }
    }

    var resolved: Lang {
        guard self == .system else { return self }
        let code = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        return Lang(rawValue: String(code)).flatMap { $0 == .system ? nil : $0 } ?? .en
    }
}

enum L10n {
    static var lang: Lang = .vi

    static func text(_ key: String) -> String {
        tables[lang.resolved]?[key] ?? tables[.en]?[key] ?? key
    }

    private static let tables: [Lang: [String: String]] = [
        .vi: [
            "menu.window": "Cửa sổ", "menu.close": "Đóng", "menu.minimize": "Thu nhỏ",
            "theme.help": "Màu bàn phím",
            "tab.keyboard": "Bàn phím", "tab.position": "Vị trí", "tab.system": "Hệ thống",
            "sec.layout": "Layout", "sec.style": "Kiểu hiển thị", "style.photo": "Ảnh thật", "style.vector": "Vẽ phẳng",
            "toggle.visible": "Hiện bàn phím", "toggle.hide": "Ẩn bàn phím", "toggle.legends": "Hiện ký tự trên phím",
            "toggle.clickThrough": "Chỉ hiển thị (click xuyên qua)", "toggle.track": "Theo dõi phím thật",
            "noLayout": "Chưa có layout", "noPreview": "Không có bản xem trước",
            "hint.keyboard": "Bấm ⌃⌥⌘K để ẩn hoặc hiện bàn phím",
            "sec.anchor": "Vị trí trên màn hình", "sec.screen": "Màn hình", "sec.size": "Kích thước & độ trong",
            "slider.scale": "Kích thước", "slider.opacity": "Độ trong", "slider.margin": "Cách mép màn hình",
            "slider.split": "Khoảng tách 2 nửa", "unit.keys": "%.1f phím", "hint.position": "Chọn một ô để neo bàn phím",
            "sec.startup": "Khởi động", "login.title": "Tự mở khi đăng nhập macOS",
            "login.detail": "Klikr mở ngay khi bạn đăng nhập.", "prelogin.title": "Hiện ở màn hình đăng nhập",
            "prelogin.detail": "Cần mật khẩu admin. Dùng cài đặt hiện tại, bật lại sau khi đổi cài đặt để cập nhật. Không áp dụng cho màn hình khoá máy và màn hình mở khoá FileVault.",
            "sec.permissions": "Quyền hệ thống", "perm.ax": "Trợ năng", "perm.ax.detail": "Để bàn phím ảo gõ được vào app khác.",
            "perm.input": "Giám sát đầu vào", "perm.input.detail": "Để hiện phím thật đang được nhấn.",
            "perm.granted": "Đã cấp quyền", "perm.grant": "Cấp quyền", "sec.errors": "Lỗi layout",
            "hint.system": "Quyền được cấp trong Cài đặt hệ thống > Quyền riêng tư & Bảo mật",
            "status.updated": "Đã cập nhật", "anchor.free": "Tự do", "sec.language": "Ngôn ngữ", "lang.system": "Theo hệ thống",
            "anchor.topLeft": "Trên - trái", "anchor.top": "Trên - giữa", "anchor.topRight": "Trên - phải",
            "anchor.left": "Giữa - trái", "anchor.center": "Chính giữa", "anchor.right": "Giữa - phải",
            "anchor.bottomLeft": "Dưới - trái", "anchor.bottom": "Dưới - giữa", "anchor.bottomRight": "Dưới - phải",
            "anchor.custom": "Tự do (kéo thả)", "screen.primary": "Màn hình chính", "screen.mouse": "Màn hình đang có con trỏ",
            "menu.photo": "Hiển thị dạng ảnh thật", "menu.missing": "⚠︎ Thiếu quyền hệ thống - mở Cài đặt",
            "menu.settings": "Cài đặt…", "menu.quit": "Thoát Klikr",
            "login.approval": "Cần cho phép Klikr trong Cài đặt > Cài đặt chung > Mục đăng nhập.",
            "login.notFound": "Hãy chạy Klikr từ file .app (ví dụ /Applications/Klikr.app) để bật mục này.",
            "error.change": "Không thể thay đổi: %@", "alert.noLayouts": "Không tìm thấy layout nào",
            "alert.noLayouts.info": "Hãy thêm file .json vào %@", "window.settings": "Klikr - Cài đặt",
        ],
        .en: [
            "menu.window": "Window", "menu.close": "Close", "menu.minimize": "Minimize",
            "theme.help": "Keyboard colours",
            "tab.keyboard": "Keyboard", "tab.position": "Position", "tab.system": "System",
            "sec.layout": "Layout", "sec.style": "Display style", "style.photo": "Photo", "style.vector": "Flat",
            "toggle.visible": "Show keyboard", "toggle.hide": "Hide keyboard", "toggle.legends": "Show key legends",
            "toggle.clickThrough": "Display only (click-through)", "toggle.track": "Track physical keys",
            "noLayout": "No layout", "noPreview": "No preview",
            "hint.keyboard": "Press ⌃⌥⌘K to show or hide the keyboard",
            "sec.anchor": "Position on screen", "sec.screen": "Display", "sec.size": "Size & opacity",
            "slider.scale": "Size", "slider.opacity": "Opacity", "slider.margin": "Edge margin",
            "slider.split": "Split gap", "unit.keys": "%.1f keys", "hint.position": "Pick a slot to anchor the keyboard",
            "sec.startup": "Startup", "login.title": "Open at macOS login",
            "login.detail": "Klikr opens as soon as you log in.", "prelogin.title": "Show on the login screen",
            "prelogin.detail": "Needs an admin password. Uses the current settings; turn it off and on again after changing settings to update them. Not available on the lock screen or the FileVault unlock screen.",
            "sec.permissions": "System permissions", "perm.ax": "Accessibility", "perm.ax.detail": "Lets the virtual keyboard type into other apps.",
            "perm.input": "Input Monitoring", "perm.input.detail": "Shows which physical keys are pressed.",
            "perm.granted": "Granted", "perm.grant": "Grant", "sec.errors": "Layout errors",
            "hint.system": "Permissions are granted in System Settings > Privacy & Security",
            "status.updated": "Updated", "anchor.free": "Free", "sec.language": "Language", "lang.system": "System",
            "anchor.topLeft": "Top left", "anchor.top": "Top center", "anchor.topRight": "Top right",
            "anchor.left": "Middle left", "anchor.center": "Center", "anchor.right": "Middle right",
            "anchor.bottomLeft": "Bottom left", "anchor.bottom": "Bottom center", "anchor.bottomRight": "Bottom right",
            "anchor.custom": "Free (drag)", "screen.primary": "Main display", "screen.mouse": "Display with the pointer",
            "menu.photo": "Show as photo", "menu.missing": "⚠︎ Missing permissions - open Settings",
            "menu.settings": "Settings…", "menu.quit": "Quit Klikr",
            "login.approval": "Allow Klikr in System Settings > General > Login Items.",
            "login.notFound": "Run Klikr from its .app (for example /Applications/Klikr.app) to turn this on.",
            "error.change": "Couldn't change: %@", "alert.noLayouts": "No layouts found",
            "alert.noLayouts.info": "Add a .json file to %@", "window.settings": "Klikr - Settings",
        ],
        .ja: [
            "menu.window": "ウインドウ", "menu.close": "閉じる", "menu.minimize": "しまう",
            "theme.help": "キーボードの色",
            "tab.keyboard": "キーボード", "tab.position": "位置", "tab.system": "システム",
            "sec.layout": "レイアウト", "sec.style": "表示スタイル", "style.photo": "写真", "style.vector": "フラット",
            "toggle.visible": "キーボードを表示", "toggle.hide": "キーボードを隠す", "toggle.legends": "キーの刻印を表示",
            "toggle.clickThrough": "表示のみ(クリック透過)", "toggle.track": "物理キーを追跡",
            "noLayout": "レイアウトなし", "noPreview": "プレビューなし",
            "hint.keyboard": "⌃⌥⌘K でキーボードを表示/非表示",
            "sec.anchor": "画面上の位置", "sec.screen": "ディスプレイ", "sec.size": "サイズと不透明度",
            "slider.scale": "サイズ", "slider.opacity": "不透明度", "slider.margin": "画面端からの距離",
            "slider.split": "左右の間隔", "unit.keys": "%.1f キー", "hint.position": "枠を選んでキーボードの位置を固定します",
            "sec.startup": "起動", "login.title": "macOS ログイン時に開く",
            "login.detail": "ログインするとすぐに Klikr が開きます。", "prelogin.title": "ログイン画面に表示",
            "prelogin.detail": "管理者パスワードが必要です。現在の設定を使います。設定を変えたらオフにしてからオンにし直して更新してください。ロック画面と FileVault のロック解除画面では使えません。",
            "sec.permissions": "システム権限", "perm.ax": "アクセシビリティ", "perm.ax.detail": "仮想キーボードで他のアプリに入力するために必要です。",
            "perm.input": "入力監視", "perm.input.detail": "押されている物理キーを表示するために必要です。",
            "perm.granted": "許可済み", "perm.grant": "許可する", "sec.errors": "レイアウトのエラー",
            "hint.system": "権限は「システム設定 > プライバシーとセキュリティ」で許可します",
            "status.updated": "更新しました", "anchor.free": "自由", "sec.language": "言語", "lang.system": "システム",
            "anchor.topLeft": "左上", "anchor.top": "上中央", "anchor.topRight": "右上",
            "anchor.left": "左中央", "anchor.center": "中央", "anchor.right": "右中央",
            "anchor.bottomLeft": "左下", "anchor.bottom": "下中央", "anchor.bottomRight": "右下",
            "anchor.custom": "自由(ドラッグ)", "screen.primary": "メインディスプレイ", "screen.mouse": "ポインタのあるディスプレイ",
            "menu.photo": "写真で表示", "menu.missing": "⚠︎ 権限が不足しています - 設定を開く",
            "menu.settings": "設定…", "menu.quit": "Klikr を終了",
            "login.approval": "「システム設定 > 一般 > ログイン項目」で Klikr を許可してください。",
            "login.notFound": "この項目を有効にするには .app (例: /Applications/Klikr.app) から Klikr を起動してください。",
            "error.change": "変更できませんでした: %@", "alert.noLayouts": "レイアウトが見つかりません",
            "alert.noLayouts.info": "%@ に .json ファイルを追加してください", "window.settings": "Klikr - 設定",
        ],
        .zh: [
            "menu.window": "窗口", "menu.close": "关闭", "menu.minimize": "最小化",
            "theme.help": "键盘颜色",
            "tab.keyboard": "键盘", "tab.position": "位置", "tab.system": "系统",
            "sec.layout": "布局", "sec.style": "显示样式", "style.photo": "实拍", "style.vector": "扁平",
            "toggle.visible": "显示键盘", "toggle.hide": "隐藏键盘", "toggle.legends": "显示键帽字符",
            "toggle.clickThrough": "仅显示(点击穿透)", "toggle.track": "跟踪实体按键",
            "noLayout": "没有布局", "noPreview": "无预览",
            "hint.keyboard": "按 ⌃⌥⌘K 显示或隐藏键盘",
            "sec.anchor": "屏幕位置", "sec.screen": "显示器", "sec.size": "大小与透明度",
            "slider.scale": "大小", "slider.opacity": "不透明度", "slider.margin": "边缘距离",
            "slider.split": "分体间距", "unit.keys": "%.1f 键", "hint.position": "选择一个位置来固定键盘",
            "sec.startup": "启动", "login.title": "登录 macOS 时打开",
            "login.detail": "登录后立即打开 Klikr。", "prelogin.title": "在登录界面显示",
            "prelogin.detail": "需要管理员密码。使用当前设置，更改设置后请关闭再打开以更新。不适用于锁屏和 FileVault 解锁界面。",
            "sec.permissions": "系统权限", "perm.ax": "辅助功能", "perm.ax.detail": "让虚拟键盘可以输入到其他应用。",
            "perm.input": "输入监控", "perm.input.detail": "用于显示正在按下的实体按键。",
            "perm.granted": "已授权", "perm.grant": "授权", "sec.errors": "布局错误",
            "hint.system": "在“系统设置 > 隐私与安全性”中授权",
            "status.updated": "已更新", "anchor.free": "自由", "sec.language": "语言", "lang.system": "跟随系统",
            "anchor.topLeft": "左上", "anchor.top": "顶部居中", "anchor.topRight": "右上",
            "anchor.left": "左侧居中", "anchor.center": "居中", "anchor.right": "右侧居中",
            "anchor.bottomLeft": "左下", "anchor.bottom": "底部居中", "anchor.bottomRight": "右下",
            "anchor.custom": "自由(拖动)", "screen.primary": "主显示器", "screen.mouse": "指针所在的显示器",
            "menu.photo": "以实拍显示", "menu.missing": "⚠︎ 缺少权限 - 打开设置",
            "menu.settings": "设置…", "menu.quit": "退出 Klikr",
            "login.approval": "请在“系统设置 > 通用 > 登录项”中允许 Klikr。",
            "login.notFound": "请从 .app (例如 /Applications/Klikr.app) 运行 Klikr 以启用此项。",
            "error.change": "无法更改: %@", "alert.noLayouts": "未找到布局",
            "alert.noLayouts.info": "请将 .json 文件添加到 %@", "window.settings": "Klikr - 设置",
        ],
        .ko: [
            "menu.window": "윈도우", "menu.close": "닫기", "menu.minimize": "최소화",
            "theme.help": "키보드 색상",
            "tab.keyboard": "키보드", "tab.position": "위치", "tab.system": "시스템",
            "sec.layout": "레이아웃", "sec.style": "표시 스타일", "style.photo": "사진", "style.vector": "플랫",
            "toggle.visible": "키보드 표시", "toggle.hide": "키보드 숨기기", "toggle.legends": "키 각인 표시",
            "toggle.clickThrough": "표시만 (클릭 통과)", "toggle.track": "실제 키 추적",
            "noLayout": "레이아웃 없음", "noPreview": "미리보기 없음",
            "hint.keyboard": "⌃⌥⌘K를 눌러 키보드 표시/숨기기",
            "sec.anchor": "화면 위치", "sec.screen": "디스플레이", "sec.size": "크기 및 불투명도",
            "slider.scale": "크기", "slider.opacity": "불투명도", "slider.margin": "가장자리 여백",
            "slider.split": "좌우 간격", "unit.keys": "%.1f 키", "hint.position": "칸을 선택해 키보드 위치를 고정하세요",
            "sec.startup": "시작", "login.title": "macOS 로그인 시 열기",
            "login.detail": "로그인하면 바로 Klikr이 열립니다.", "prelogin.title": "로그인 화면에 표시",
            "prelogin.detail": "관리자 암호가 필요합니다. 현재 설정을 사용하며, 설정을 바꾼 뒤에는 껐다 켜서 업데이트하세요. 잠금 화면과 FileVault 잠금 해제 화면에서는 사용할 수 없습니다.",
            "sec.permissions": "시스템 권한", "perm.ax": "손쉬운 사용", "perm.ax.detail": "가상 키보드로 다른 앱에 입력하려면 필요합니다.",
            "perm.input": "입력 모니터링", "perm.input.detail": "눌린 실제 키를 표시하려면 필요합니다.",
            "perm.granted": "허용됨", "perm.grant": "허용", "sec.errors": "레이아웃 오류",
            "hint.system": "권한은 시스템 설정 > 개인정보 보호 및 보안에서 허용합니다",
            "status.updated": "업데이트됨", "anchor.free": "자유", "sec.language": "언어", "lang.system": "시스템",
            "anchor.topLeft": "왼쪽 위", "anchor.top": "위 가운데", "anchor.topRight": "오른쪽 위",
            "anchor.left": "왼쪽 가운데", "anchor.center": "가운데", "anchor.right": "오른쪽 가운데",
            "anchor.bottomLeft": "왼쪽 아래", "anchor.bottom": "아래 가운데", "anchor.bottomRight": "오른쪽 아래",
            "anchor.custom": "자유 (드래그)", "screen.primary": "주 디스플레이", "screen.mouse": "포인터가 있는 디스플레이",
            "menu.photo": "사진으로 표시", "menu.missing": "⚠︎ 권한 부족 - 설정 열기",
            "menu.settings": "설정…", "menu.quit": "Klikr 종료",
            "login.approval": "시스템 설정 > 일반 > 로그인 항목에서 Klikr을 허용하세요.",
            "login.notFound": "이 항목을 켜려면 .app (예: /Applications/Klikr.app)에서 Klikr을 실행하세요.",
            "error.change": "변경할 수 없습니다: %@", "alert.noLayouts": "레이아웃을 찾을 수 없음",
            "alert.noLayouts.info": "%@에 .json 파일을 추가하세요", "window.settings": "Klikr - 설정",
        ],
    ]
}

/// Localized UI string for `key` in the current language.
func L(_ key: String) -> String { L10n.text(key) }

/// Localized format string for `key`, filled with `args`.
func L(_ key: String, _ args: CVarArg...) -> String { String(format: L10n.text(key), arguments: args) }
