//
//  SwiftUISheetExtension.swift
//  SwiftUISheetExtension
//
//  Created by yuki on 2025/01/05.
//

import SwiftUI
import UIKit

public struct DismissSheetAction: Equatable {
    let dismiss: () -> Void
    
    public static func == (lhs: DismissSheetAction, rhs: DismissSheetAction) -> Bool { false }
    
    public func callAsFunction() {
        self.dismiss()
    }
}

extension EnvironmentValues {
    @Entry public var dismissSheet: DismissSheetAction = DismissSheetAction(dismiss: {})
}

private struct IsPresented: Identifiable {
    let id = 0
    
    static let instance = IsPresented()
}

extension View {
    public func sheet_<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        // Item is Identifiable so that the current sheet is closed and a new sheet is displayed when Item is changed.
        // At this time, since isPresented always takes only two values of true/false, IsPresented.instance is assigned to true to be regarded as the same value.
        // The Coordinator determines "the same", so it is not a problem that multiple sheet_ have the same IsPresented.instance.
        self.sheet_(
            item: Binding<IsPresented?>(
                get: { isPresented.wrappedValue ? IsPresented.instance : nil },
                set: { isPresented.wrappedValue = $0 != nil }
            ),
            onDismiss: onDismiss
        ) { _ in
            content()
        }
    }
    
    public func sheet_<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        self.modifier(
            SheetModifier(
                item: item,
                onDismiss: onDismiss,
                sheetContent: content
            )
        )
    }
    
    nonisolated public func onInteractiveDismissAttempt_(_ action: @escaping () -> Void) -> some View {
        self.preference(
            key: OnInteractiveDismissAttemptPreferenceKey.self,
            value: OnInteractiveDismissAttemptClosure(closure: action)
        )
    }
}

private struct OnInteractiveDismissAttemptClosure: Equatable, @unchecked Sendable {
    let closure: () -> Void
    
    static func == (lhs: Self, rhs: Self) -> Bool { false }
}

private struct OnInteractiveDismissAttemptPreferenceKey: PreferenceKey {
    static let defaultValue: OnInteractiveDismissAttemptClosure? = nil
    
    static func reduce(
        value: inout OnInteractiveDismissAttemptClosure?,
        nextValue: () -> OnInteractiveDismissAttemptClosure?
    ) {
        value = nextValue()
    }
}

private struct SheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    
    let onDismiss: (() -> Void)?
    
    let sheetContent: (Item) -> SheetContent
    
    func body(content parent: Content) -> some View {
        parent
            .background(
                SheetContainer(
                    item: self.$item,
                    onDismiss: self.onDismiss,
                    sheetContent: self.sheetContent
                )
            )
    }
}

private struct SheetContainer<Item: Identifiable, SheetContent: View>: UIViewControllerRepresentable {
    @Binding var item: Item?

    let onDismiss: (() -> Void)?
    
    let sheetContent: (Item) -> SheetContent

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> SheetPresentationController {
        SheetPresentationController()
    }

    func updateUIViewController(_ uiViewController: SheetPresentationController, context: Context) {
        let isAlreadyPresented = uiViewController.presentingHostingController != nil
        let isItemUpdated = context.coordinator.currentItemID != self.item?.id
        context.coordinator.currentItemID = self.item?.id
        
        func present(for item: Item) {
            let hostingController = UIHostingController(
                rootView: self.sheetContent(item)
                    .environment(\.dismissSheet, DismissSheetAction(dismiss: {
                        self.item = nil
                    }))
                    .onPreferenceChange(OnInteractiveDismissAttemptPreferenceKey.self) { value in
                        MainActor.assumeIsolated{
                            context.coordinator.onInteractiveDismissAttempt = value?.closure
                        }
                    }
            )
            hostingController.presentationController?.delegate = context.coordinator
            uiViewController.present(hostingController, animated: true)
            uiViewController.presentingHostingController = hostingController
        }
        
        func dismiss() {
            // If you use the completion of dismiss to delay calling present, the state of SwiftUI may become inconsistent.
            // The present is automatically delayed by the UIKit mechanism, so it is okay to call present immediately after dismiss.
            uiViewController.presentingHostingController?.dismiss(animated: true)
            uiViewController.presentingHostingController = nil
        }
        
        if let item = item {
            // 1) The item is not nil and has been updated, and is already displayed
            if isItemUpdated, isAlreadyPresented {
                dismiss()
                present(for: item)
            }
            
            // 2) The item is not nil and has been updated, and is not displayed
            if !isAlreadyPresented {
                present(for: item)
            }
        } else {
            // 3) The item is nil, and is already displayed
            if isAlreadyPresented {
                dismiss()
            }
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        let parent: SheetContainer
        
        var currentItemID: Item.ID?
        
        var onInteractiveDismissAttempt: (() -> Void)?
        
        init(parent: SheetContainer) {
            self.parent = parent
        }
        
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            self.parent.item = nil
            self.parent.onDismiss?()
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            self.onInteractiveDismissAttempt?()
        }
    }
}

final private class SheetPresentationController: UIViewController {
    weak var presentingHostingController: UIViewController?
}
