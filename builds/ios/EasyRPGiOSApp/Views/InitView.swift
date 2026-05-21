import UIKit
import SwiftUI

struct InitView: View {
    private static let tutorialURL = URL(string: "https://www.youtube.com/watch?v=r9qU-6P3HOs")
    private static let websiteURL = URL(string: "https://easyrpg.org")
    @State private var showFolderPicker = false
    @State private var useAutomaticPath = true
    @StateObject private var config = ConfigManager.shared
    var showContinueToBrowserButton = false

    init(showContinueToBrowserButton: Bool = false) {
        self.showContinueToBrowserButton = showContinueToBrowserButton
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("EasyRPG Player へようこそ")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("RPG 2000 / 2003 のゲームをプレイしましょう")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("ゲームフォルダの設定").font(.headline)

                    Picker("設定方式", selection: $useAutomaticPath) {
                        Text("自動 (Documents)").tag(true)
                        Text("任意パス").tag(false)
                    }
                    .pickerStyle(.segmented)

                    Text("ゲームを格納するフォルダを選択してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: {
                        if useAutomaticPath {
                            config.useAutomaticEasyRPGFolderInDocuments()
                        } else {
                            showFolderPicker = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "folder.circle.fill")
                            Text(useAutomaticPath ? "Documentsを自動設定" : "ゲームフォルダを選択")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)

                    if let folder = config.easyRPGFolderURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("選択済み:").font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(folder.lastPathComponent)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 12)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("推奨フォルダ構成").font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EasyRPG/").font(.caption2).monospaced().fontWeight(.semibold)
                        Text("├── games/       (ゲームフォルダ)").font(.caption2).monospaced().foregroundStyle(.secondary)
                        Text("├── saves/       (保存ファイル)").font(.caption2).monospaced().foregroundStyle(.secondary)
                        Text("├── soundfonts/  (カスタムサウンドフォント)").font(.caption2).monospaced().foregroundStyle(.secondary)
                        Text("├── fonts/       (カスタムフォント)").font(.caption2).monospaced().foregroundStyle(.secondary)
                        Text("└── rtp/         (ランタイムパッケージ)").font(.caption2).monospaced().foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
                }
                .padding(.vertical, 12)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("2000/2003のゲームを見つけるには")
                        .font(.headline)

                    Text("• ファイルマネージャで EasyRPG フォルダにゲームを配置してください\n• RPG_RT.ldb、RPG_RT.lmt、RPG_RT.ini など、RPG 2000/2003 のデータファイルが含まれるフォルダはゲームとして認識されます\n• ZIP ファイルの配置にも対応しています")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding(.vertical, 12)

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    if showContinueToBrowserButton {
                        Button(action: { config.completeOnboardingIfNeeded() }) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("ゲームブラウザへ移動")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                        }
                    }

                    if let tutorialURL = Self.tutorialURL {
                        Link(destination: tutorialURL) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("説明動画を見る")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .cornerRadius(8)
                        }
                    }

                    if let websiteURL = Self.websiteURL {
                        Link(destination: websiteURL) {
                            HStack {
                                Image(systemName: "globe")
                                Text("公式サイトを訪問")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .navigationTitle("EasyRPG Player")
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView { url in
                config.setEasyRPGFolder(url)
            }
        }
        .onAppear {
            AppLogger.log("InitView onAppear")
            if let folder = config.easyRPGFolderURL {
                useAutomaticPath = folder.path.hasPrefix((FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "") + "/") || folder.path == FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path
            }
        }
    }
}

#Preview {
    InitView()
}
