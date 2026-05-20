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
    @State private var viewModeDialog = false
    @State private var selectedGame: Game? = nil
    @State private var showGameOptions = false
    @State private var showCustomTitleEditor = false

    private var filtered: [Game] {
        let source = favoritesOnly ? library.games.filter(\.favorite) : library.games
        guard !query.isEmpty else { return source }
        return source.filter {
            $0.getDisplayTitle(labelMode: config.gameBrowserLabelMode).localizedCaseInsensitiveContains(query) ||
            $0.path.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Group {
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
                Button { viewModeDialog = true } label: { Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2") }
                Button(action: onOpenSettings) { Image(systemName: "gearshape.fill") }
            }
        }
        .sheet(isPresented: $showMenu) {
            BrowserDrawerSheet(
                favoritesOnly: $favoritesOnly,
                onOpenSettings: onOpenSettings
            )
        }
        .confirmationDialog("表示", isPresented: $viewModeDialog, presenting: true) { _ in
            Button("グリッド表示") { isGridMode = true }
            Button("リスト表示") { isGridMode = false }
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
        .onAppear { library.reloadGames() }
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
                    Button(action: { dismiss(); onOpenSettings() }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("設定")
                        }
                    }
                    Toggle("お気に入りのみ表示", isOn: $favoritesOnly)
                    Link(destination: URL(string: "https://easyrpg.org")!) {
                        HStack {
                            Image(systemName: "globe")
                            Text("公式サイト")
                        }
                    }
                    Link(destination: URL(string: "https://github.com/EasyRPG/Player/issues")!) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text("バグ報告")
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


struct LoadingPanelView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            ProgressView("ロード中…")
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct BrowserGridView: View {
    let games: [Game]
    let onPlay: (Game) -> Void
    let onFavoriteToggle: (Game) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(games) { game in
                    Button { onPlay(game) } label: {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.25)], startPoint: .bottom, endPoint: .top))
                                .frame(height: 210)
                                .overlay(
                                    VStack {
                                        Spacer()
                                        Text(game.path).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(2).multilineTextAlignment(.center)
                                        Text(game.title).font(.title3.bold()).foregroundStyle(.white).lineLimit(1)
                                    }.padding(8)
                                )
                            VStack(spacing: 6) {
                                FavoriteStarButton(game: game, onToggle: onFavoriteToggle)
                                Image(systemName: "gearshape.fill").foregroundStyle(.white).padding(6)
                            }.padding(8)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct BrowserListView: View {
    let games: [Game]
    let onPlay: (Game) -> Void
    let onFavoriteToggle: (Game) -> Void

    var body: some View {
        List(games) { game in
            Button { onPlay(game) } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.3)).frame(width: 120, height: 90)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title).font(.headline)
                        Text(game.path).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.fill").foregroundStyle(.secondary)
                        FavoriteStarButton(game: game, onToggle: onFavoriteToggle)
                    }
                }
            }
        }
    }
}

struct FavoriteStarButton: View {
    let game: Game
    let onToggle: (Game) -> Void

    var body: some View {
        Button { onToggle(game) } label: {
            Image(systemName: game.favorite ? "star.fill" : "star")
                .foregroundStyle(game.favorite ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
    }
}
