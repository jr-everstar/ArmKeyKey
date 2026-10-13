import SwiftUI
import AppKit

struct LicenseEntry: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let license: String
    let credit: String
    let description: String
    var resource: String? = nil
    var attribution: String? = nil
    var link: URL? = nil

    static let entries: [LicenseEntry] = [
        .init(id: "armkeykey", name: "ArmKeyKey", subtitle: "設計與開發", symbol: "keyboard", license: "BSD 3-Clause", credit: "© 2026 jr-everstar", description: "熟悉的輸入體驗，全新的 Mac。\n\nArmKeyKey 原創程式碼及素材採用 BSD 3-Clause 授權。第三方程式碼、字詞資料及系統素材保留各自的授權。", resource: "ArmKeyKey-LICENSE"),
        .init(id: "openvanilla", name: "OpenVanilla", subtitle: "輸入引擎 · PlainVanilla", symbol: "curlybraces", license: "MIT-style", credit: "The OpenVanilla Project · Lukhnos D. Liu · Weizhong Yang", description: "倉頡與速成沿用 OpenVanilla Generic 輸入引擎，以及 OpenVanilla、PlainVanilla 的候選字與文字緩衝元件。感謝原作者的開源貢獻。", resource: "OpenVanilla-LICENSE"),
        .init(id: "yahoo", name: "YahooKeyKey", subtitle: "原始來源套件", symbol: "archivebox", license: "BSD 3-Clause", credit: "© 2012 Yahoo! Inc.", description: "保留自 YahooKeyKey 1.1.2528 來源套件的版權及授權聲明。元件本身的個別授權亦一併保留。使用來源名稱不表示原作者或機構認可本產品。", resource: "YahooKeyKey-LICENSE"),
        .init(id: "rime", name: "Rime Cantonese", subtitle: "粵拼字詞與聯想詞", symbol: "text.bubble", license: "CC BY 4.0", credit: "CanCLID 及 Rime Cantonese 貢獻者", description: "粵拼字詞與詞頻資料經轉換及建立索引，用於離線查找與聯想詞。此處使用字詞資料，並未使用 Rime 執行引擎。", resource: "RimeCantonese-LICENSE", attribution: "RimeCantonese-Attribution", link: URL(string: "https://github.com/rime/rime-cantonese/tree/259f0e48bba840c3a2e0d117539e96937f3d89bc")),
        .init(id: "noto", name: "Noto Sans TC", subtitle: "內嵌候選字型", symbol: "textformat", license: "SIL OFL 1.1", credit: "Adobe · Noto 專案貢獻者", description: "App 隨附 Noto Sans TC 字型，僅在本 App 內載入，無需另外安裝。字型並未涵蓋所有 Unicode 擴充漢字。", resource: "NotoSansTC-LICENSE", attribution: "NotoSansTC-Attribution", link: URL(string: "https://github.com/google/fonts/tree/main/ofl/notosanstc")),
        .init(id: "sqlite", name: "SQLite", subtitle: "本機資料儲存", symbol: "externaldrive", license: "Public Domain", credit: "SQLite authors", description: "使用 macOS 提供的 SQLite 系統函式庫，儲存字典索引及個人選字順序。SQLite 上游程式碼屬公有領域；本 App 沒有附帶獨立 SQLite 實作或專有擴充。", link: URL(string: "https://www.sqlite.org/copyright.html")),
        .init(id: "apple", name: "Apple 平台", subtitle: "原生介面與系統整合", symbol: "macwindow", license: "系統元件", credit: "Apple Inc.", description: "使用 AppKit、SwiftUI、Foundation、InputMethodKit、Carbon 及 UniformTypeIdentifiers，以及平台提供的 Swift / C++ 執行環境。\n\n圖示由專案繪圖程式產生，使用系統字型，沒有附帶 Apple 字型檔或 Yahoo 圖像。系統素材不受 ArmKeyKey 的 BSD 授權涵蓋。"),
        .init(id: "tables", name: "倉頡與速成字表", subtitle: "資料來源與原始聲明", symbol: "character.book.closed", license: "上游原始聲明", credit: "CNS11643 · opendesktop.org.tw · yylin · b6s", description: "字表取自 YahooKeyKey 1.1.2528。速成字表與 OpenVanilla 官方 simplex-ext.cin 完全相同，包含擴充字及排序；倉頡字表具相同來源記載，但版本內容有差異。\n\n依 OpenVanilla 的方式保留原始作者、字表檔頭及授權文字。OpenVanilla 專案採用 MIT；其授權全文指示字表另參閱各自檔案。", resource: "OpenVanilla-LICENSE", attribution: "LicensingOverview", link: URL(string: "https://openvanilla.org/")),
        .init(id: "all", name: "完整聲明", subtitle: "全部版權及授權原文", symbol: "doc.text", license: "授權彙編", credit: "ArmKeyKey 與第三方貢獻者", description: "此處完整保留所有版權、授權條款、來源署名及免責聲明。原文維持原有語言。", resource: "ThirdPartyNotices")
    ]
}

struct LicenseDetailView: View {
    let entry: LicenseEntry
    private let accent = Color(red: 0.05, green: 0.48, blue: 0.64)
    var body: some View { detail(entry).id(entry.id) }

    private func textResource(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "無法讀取授權內容。請重新安裝完整的 ArmKeyKey App。"
        }
        return text
    }

    private func detail(_ item: LicenseEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        if item.id == "armkeykey" {
                            Image(nsImage: NSImage(named: "ArmKeyKey") ?? NSApp.applicationIconImage)
                                .resizable().interpolation(.high).scaledToFit().frame(width: 48, height: 48)
                                .accessibilityLabel("ArmKeyKey")
                        } else {
                            Image(systemName: item.symbol).font(.system(size: 27, weight: .light)).foregroundStyle(accent)
                        }
                        Spacer()
                        Text(item.license).font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(accent.opacity(0.1), in: Capsule())
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(item.name).font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(item.subtitle).font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    Divider()
                    Text(item.credit).font(.system(size: 13, weight: .medium)).textSelection(.enabled)
                }.padding(25)
                    .background(LinearGradient(colors: [accent.opacity(0.09), Color(nsColor: .controlBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
                Text(item.description).font(.system(size: 14)).lineSpacing(6).textSelection(.enabled)
                if let link = item.link {
                    Link(destination: link) { Label("查看來源網站", systemImage: "arrow.up.right.square") }.font(.system(size: 13, weight: .medium))
                }
                if let attribution = item.attribution {
                    document(title: "來源與修改說明", text: textResource(attribution))
                }
                if let resource = item.resource {
                    document(title: "完整授權條款", text: textResource(resource))
                }
                Text("第三方名稱僅作來源識別，不代表相關作者或機構背書。")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            }.padding(30).frame(maxWidth: 850, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color(nsColor: .windowBackgroundColor))
    }

    private func document(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: { Label("複製", systemImage: "doc.on.doc") }
                .buttonStyle(.borderless).help("複製完整原文")
            }
            Divider()
            Text(text).font(.system(size: 12)).lineSpacing(5).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
    }
}
