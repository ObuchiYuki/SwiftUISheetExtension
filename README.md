**README.md (English)**

# SwiftUISheetExtension

A SwiftUI extension that provides `sheet_`, behaving like the standard `sheet`, but with two extra features:

- `@Environment(\.dismissSheet)` to programmatically dismiss the currently presented sheet  
- `onDismissAttempt_`, triggered only if you’ve set `interactiveDismissDisabled(true)` and the user attempts to dismiss

## Usage

**Presenting a sheet**  
```swift
@State private var isSheetPresented = false

Button("Open Sheet") {
    isSheetPresented = true
}
.sheet_(
    isPresented: $isSheetPresented,
    onDismiss: { print("Sheet dismissed") }
) {
    SheetContentView()
}
```

**Dismissing from inside**  
```swift
@Environment(\.dismissSheet) private var dismissSheet

Button("Dismiss") {
    dismissSheet()
}
```

**Intercepting dismiss** (requires `interactiveDismissDisabled(true)`)  
```swift
@Environment(\.dismissSheet) private var dismissSheet

.interactiveDismissDisabled(true)
.onDismissAttempt_ {
    showAlert = true
}
.alert("Dismiss?", isPresented: $showAlert) {
    Button("Cancel", role: .cancel) {}
    Button("Dismiss", role: .destructive) {
        dismissSheet()
    }
}
```

