# SwiftUISheetExtension

SwiftUI の `sheet` と同様に使える `sheet_` を提供し、次の機能を追加します:

- `@Environment(\.dismissSheet)` で現在のシートをプログラム的に閉じられる  
- `interactiveDismissDisabled(true)` 設定時にユーザーのシート閉じ操作をフックする `onDismissAttempt_`

## 使い方

**シートを表示する**  
```swift
@State private var isSheetPresented = false

Button("シートを開く") {
    isSheetPresented = true
}
.sheet_(
    isPresented: $isSheetPresented,
    onDismiss: { print("シートが閉じられました") }
) {
    SheetContentView()
}
```

**シート内部から閉じる**  
```swift
@Environment(\.dismissSheet) private var dismissSheet

Button("閉じる") {
    dismissSheet()
}
```

**閉じようとしたタイミングをフック**（`interactiveDismissDisabled(true)` が必要）  
```swift
@Environment(\.dismissSheet) private var dismissSheet

.interactiveDismissDisabled(true)
.onDismissAttempt_ {
    showAlert = true
}
.alert("シートを閉じますか？", isPresented: $showAlert) {
    Button("キャンセル", role: .cancel) {}
    Button("閉じる", role: .destructive) {
        dismissSheet()
    }
}
```
