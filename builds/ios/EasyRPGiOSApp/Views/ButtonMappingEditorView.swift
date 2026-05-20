import SwiftUI

struct ButtonMappingEditorView: View {
    @StateObject private var store = ButtonMappingStore()

    var body: some View {
        Form {
            ForEach($store.mappings) { $item in
                VStack(alignment: .leading) {
                    Text(item.label)
                    HStack {
                        Text(item.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 110, alignment: .leading)
                        Picker("キー", selection: $item.key) {
                            ForEach(ButtonMappingStore.supportedKeys, id: \.self) { key in
                                Text(key).tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .navigationTitle("ボタン設定")
        .onAppear {
            store.load()
        }
        .onChange(of: store.mappings) { _, _ in
            store.save()
            store.applyToPlayer()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("保存") {
                    store.save()
                    store.applyToPlayer()
                }
                Button("リセット") {
                    store.reset()
                    PlayerBridge.resetButtonMappings()
                    store.applyToPlayer()
                }
            }
        }
    }
}
