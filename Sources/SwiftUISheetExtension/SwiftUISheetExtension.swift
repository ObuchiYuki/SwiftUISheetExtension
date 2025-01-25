//
//  SwiftUISheetExtension.swift
//  SwiftUISheetExtension
//
//  Created by yuki on 2025/01/05.
//

import SwiftUI
import UIKit

public struct DismissSheetAction: Equatable {
    @usableFromInline let dismiss: () -> Void
    
    @inlinable public init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }
    
    @inlinable public static func == (lhs: DismissSheetAction, rhs: DismissSheetAction) -> Bool { false }
    
    @inlinable public func callAsFunction() {
        self.dismiss()
    }
}

extension EnvironmentValues {
    @Entry public var dismissSheet: DismissSheetAction = DismissSheetAction(dismiss: {
        assertionFailure("The dismissSheet action is not available outside of a sheet.")
    })
}

@usableFromInline struct IsPresented: Identifiable, Sendable {
    @usableFromInline let id = 0
    
    @usableFromInline static let instance = IsPresented()
    
    @inlinable init() {}
}

extension View {
    @inlinable public func sheet_<SheetContent: View>(
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
    
    @inlinable public func sheet_<Item: Identifiable, SheetContent: View>(
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
    
    @inlinable nonisolated public func onInteractiveDismissAttempt_(_ action: @escaping () -> Void) -> some View {
        self.preference(
            key: OnInteractiveDismissAttemptPreferenceKey.self,
            value: OnInteractiveDismissAttemptClosure(closure: action)
        )
    }
}

@usableFromInline struct OnInteractiveDismissAttemptClosure: Equatable, @unchecked Sendable {
    @usableFromInline let closure: () -> Void
    
    @inlinable static func == (lhs: Self, rhs: Self) -> Bool { false }
    
    @inlinable init(closure: @escaping () -> Void) {
        self.closure = closure
    }
}

@usableFromInline struct OnInteractiveDismissAttemptPreferenceKey: PreferenceKey {
    @usableFromInline static let defaultValue: OnInteractiveDismissAttemptClosure? = nil
    
    @inlinable static func reduce(
        value: inout OnInteractiveDismissAttemptClosure?,
        nextValue: () -> OnInteractiveDismissAttemptClosure?
    ) {
        value = nextValue()
    }
}

@usableFromInline struct SheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @usableFromInline @Binding var item: Item?
    
    @usableFromInline let onDismiss: (() -> Void)?
    
    @usableFromInline let sheetContent: (Item) -> SheetContent
    
    @usableFromInline init(
        item: Binding<Item?>,
        onDismiss: (() -> Void)?,
        sheetContent: @escaping (Item) -> SheetContent
    ) {
        self._item = item
        self.onDismiss = onDismiss
        self.sheetContent = sheetContent
    }
    
    @usableFromInline func body(content parent: Content) -> some View {
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

@usableFromInline struct SheetContainer<Item: Identifiable, SheetContent: View>: UIViewControllerRepresentable {
    @usableFromInline @Binding var item: Item?

    @usableFromInline let onDismiss: (() -> Void)?
    
    @usableFromInline let sheetContent: (Item) -> SheetContent

    @inlinable func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @inlinable func makeUIViewController(context: Context) -> SheetPresentationController {
        SheetPresentationController()
    }

    @inlinable func updateUIViewController(_ uiViewController: SheetPresentationController, context: Context) {
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

    @usableFromInline final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        @usableFromInline let parent: SheetContainer
        
        @usableFromInline var currentItemID: Item.ID?
        
        @usableFromInline var onInteractiveDismissAttempt: (() -> Void)?
        
        @inlinable init(parent: SheetContainer) {
            self.parent = parent
        }
        
        @inlinable func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            self.parent.item = nil
            self.parent.onDismiss?()
        }

        @inlinable func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            self.onInteractiveDismissAttempt?()
        }
    }
}

@usableFromInline
final class SheetPresentationController: UIViewController {
    @usableFromInline weak var presentingHostingController: UIViewController?
}
