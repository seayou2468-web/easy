import SwiftUI

struct GameBrowserView: View {
    let onOpenSettings: () -> Void
    let onPlay: (Game) -> Void

    @ObservedObject var library: GameLibrary
    @StateObject private var config = ConfigManager.shared
    @State private var query = ""
    @State private var isGridMode = true
    @State private var favoritesOnly = false
    @State private var showMenu = false
    @State private var selectedGame: Game? = nil
    @State private var showGameOptions = false
    @State private var showCustomTitleEditor = false
    @State private var sortMode = 0
    @State private var showDisplayModeSheet = false

    private var filtered: [Game] {
        let source = favoritesOnly ? library.games.filter(\.favorite) : library.games
        let searched = query.isEmpty ? source : source.filter {
            $0.getDisplayTitle(labelMode: config.gameBrowserLabelMode).localizedCaseInsensitiveContains(query) ||
            $0.path.localizedCaseInsensitiveContains(query)
        }
        switch sortMode {
        case 1:
            return searched.sorted { $0.getDisplayTitle(labelMode: config.gameBrowserLabelMode) < $1.getDisplayTitle(labelMode: config.gameBrowserLabelMode) }
        case 2:
            return searched.sorted { $0.gameFolderName < $1.gameFolderName }
        default:
            return searched
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                BrowserHeroBar(
                    totalCount: library.games.count,
                    shownCount: filtered.count,
                    favoritesOnly: favoritesOnly,
                    showDisplayModeSheet: $showDisplayModeSheet
                )
                .padding(.horizontal, 12)
                if library.isScanning {
                    LoadingPanelView()
                } else if filtered.isEmpty {
                    BrowserErrorPanelView(message: "ゲームが見つかりません。設定からゲームフォルダを選択してリフレッシュしてください。")
                } else if isGridMode {
                    BrowserGridView(
                        games: filtered,
                        labelMode: config.gameBrowserLabelMode,
                        onPlay: onPlay,
                        onGameOptionsOpen: { game in
                            selectedGame = game
                            showGameOptions = true
                        },
                        onFavoriteToggle: library.toggleFavorite
                    )
                } else {
                    BrowserListView(
                        games: filtered,
                        labelMode: config.gameBrowserLabelMode,
                        onPlay: onPlay,
                        onGameOptionsOpen: { game in
                            selectedGame = game
                            showGameOptions = true
                        },
                        onFavoriteToggle: library.toggleFavorite
                    )
                }
            }
        }
        .navigationTitle("EasyRPG Player")
        .searchable(text: $query, prompt: "ゲームを検索")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showMenu = true } label: { Image(systemName: "line.3.horizontal") }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { library.reloadGames(forceScan: true) } label: { Image(systemName: "arrow.clockwise") }
                Button(action: onOpenSettings) { Image(systemName: "gearshape.fill") }
            }
        }
        .sheet(isPresented: $showMenu) {
            BrowserDrawerSheet(
                favoritesOnly: $favoritesOnly,
                onOpenSettings: onOpenSettings
            )
        }
        .sheet(isPresented: $showGameOptions) {
            if let game = selectedGame {
                GameOptionsSheet(
                    game: game,
                    onCustomTitleEdit: { showCustomTitleEditor = true },
                    onPlay: { onPlay(game) }
                )
            }
        }
        .sheet(isPresented: $showCustomTitleEditor) {
            if let game = selectedGame {
                CustomTitleEditorSheet(game: game)
            }
        }
        .confirmationDialog("表示設定", isPresented: $showDisplayModeSheet) {
            Button(favoritesOnly ? "お気に入り表示を解除" : "お気に入りだけ表示") {
                favoritesOnly.toggle()
            }
            Button(isGridMode ? "リスト表示" : "グリッド表示") {
                isGridMode.toggle()
            }
            Button("並び替え: おすすめ") { sortMode = 0 }
            Button("並び替え: タイトル順") { sortMode = 1 }
            Button("並び替え: フォルダ順") { sortMode = 2 }
        }
        .onAppear { AppLogger.log("GameBrowserView onAppear"); library.reloadGames() }
    }
}

struct BrowserHeroBar: View {
    let totalCount: Int
    let shownCount: Int
    let favoritesOnly: Bool
    @Binding var showDisplayModeSheet: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ゲームライブラリ")
                    .font(.headline)
                Text("\(shownCount) / \(totalCount) 本表示" + (favoritesOnly ? " ・ お気に入りのみ" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { showDisplayModeSheet = true }) {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct BrowserGridView: View {
    let games: [Game]
    let labelMode: Int
    let onPlay: (Game) -> Void
    let onGameOptionsOpen: (Game) -> Void
    let onFavoriteToggle: (Game) -> Void

    @Environment(\.horizontalSizeClass) var sizeClass

    private var columns: [GridItem] {
        let count = sizeClass == .compact ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(games) { game in
                    BrowserGameCard(
                        game: game,
                        labelMode: labelMode,
                        onPlay: { onPlay(game) },
                        onOptionsOpen: { onGameOptionsOpen(game) },
                        onFavoriteToggle: { onFavoriteToggle(game) }
                    )
                }
            }
            .padding(12)
        }
    }
}

struct BrowserListView: View {
    let games: [Game]
    let labelMode: Int
    let onPlay: (Game) -> Void
    let onGameOptionsOpen: (Game) -> Void
    let onFavoriteToggle: (Game) -> Void

    var body: some View {
        List {
            ForEach(games) { game in
                BrowserGameListRow(
                    game: game,
                    labelMode: labelMode,
                    onPlay: { onPlay(game) },
                    onOptionsOpen: { onGameOptionsOpen(game) },
                    onFavoriteToggle: { onFavoriteToggle(game) }
                )
            }
        }
        .listStyle(.plain)
    }
}

struct BrowserGameCard: View {
    let game: Game
    let labelMode: Int
    let onPlay: () -> Void
    let onOptionsOpen: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let titleImage = game.titleImage {
                    Image(uiImage: titleImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                        .overlay(
                            Text("ゲーム画像なし")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        )
                }

                Button(action: onFavoriteToggle) {
                    Image(systemName: game.favorite ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundStyle(game.favorite ? .yellow : .white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(6)
            }
            .frame(height: 120)
            .cornerRadius(8)
            .onTapGesture(count: 2) { onPlay() }

            VStack(alignment: .leading, spacing: 4) {
                Text(game.getDisplayTitle(labelMode: labelMode))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.bordered)

                    Button(action: onOptionsOpen) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .font(.caption)
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct BrowserGameListRow: View {
    let game: Game
    let labelMode: Int
    let onPlay: () -> Void
    let onOptionsOpen: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let titleImage = game.titleImage {
                Image(uiImage: titleImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(game.getDisplayTitle(labelMode: labelMode))
                    .font(.body)
                    .fontWeight(.semibold)

                Text(game.gameFolderName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onFavoriteToggle) {
                    Image(systemName: game.favorite ? "star.fill" : "star")
                        .foregroundStyle(game.favorite ? .yellow : .gray)
                }

                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                }

                Button(action: onOptionsOpen) {
                    Image(systemName: "ellipsis")
                }
            }
            .font(.system(size: 18))
        }
        .padding(.vertical, 8)
    }
}

struct GameOptionsSheet: View {
    let game: Game
    let onCustomTitleEdit: () -> Void
    let onPlay: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("ゲーム情報")) {
                    HStack {
                        Text("タイトル")
                        Spacer()
                        Text(game.title).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("フォルダ")
                        Spacer()
                        Text(game.gameFolderName).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("パス")
                        Spacer()
                        Text(game.path).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("操作")) {
                    Button(action: { dismiss(); onPlay() }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("プレイ")
                        }
                    }
                    Button(action: { dismiss(); onCustomTitleEdit() }) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                            Text("カスタムタイトルを編集")
                        }
                    }
                }
            }
            .navigationTitle("ゲーム詳細")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct CustomTitleEditorSheet: View {
    let game: Game
    @State private var customTitle = ""
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("カスタムタイトルを設定")) {
                    TextField("新しいタイトル", text: $customTitle)
                }

                Section {
                    Button("保存") {
                        ConfigManager.shared.setCustomGameTitle(customTitle, for: game.path)
                        dismiss()
                    }
                    .disabled(customTitle.isEmpty)

                    if !game.customTitle.isNilOrEmpty {
                        Button("リセット", role: .destructive) {
                            ConfigManager.shared.setCustomGameTitle("", for: game.path)
                            dismiss()
                        }
                    } 
                }
            }
            .navigationTitle("タイトル編集")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                customTitle = game.customTitle ?? ""
            }
        }
    }
}

struct BrowserDrawerSheet: View {
    private static let websiteURL = URL(string: "https://easyrpg.org")
    private static let issuesURL = URL(string: "https://github.com/EasyRPG/Player/issues")

    @Binding var favoritesOnly: Bool
    let onOpenSettings: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EasyRPG Player").font(.headline)
                        Text("RPG 2000/2003 Games").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("ナビゲーション") {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenSettings() }
                    }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("設定")
                        }
                    }
                    Toggle("お気に入りのみ表示", isOn: $favoritesOnly)
                    if let websiteURL = Self.websiteURL {
                        Link(destination: websiteURL) {
                            HStack {
                                Image(systemName: "globe")
                                Text("公式サイト")
                            }
                        }
                    }
                    if let issuesURL = Self.issuesURL {
                        Link(destination: issuesURL) {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                Text("バグ報告")
                            }
                        }
                    }
                }
            }
            .navigationTitle("メニュー")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct BrowserErrorPanelView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("ゲームが見つかりません")
                .font(.headline)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

struct LoadingPanelView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("ゲームをスキャン中...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
