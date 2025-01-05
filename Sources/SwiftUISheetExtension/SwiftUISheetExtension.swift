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

extension View {
    public func sheet_<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        self.sheet_(item: Binding<Optional<Void>>(
            get: { isPresented.wrappedValue ? () : nil },
            set: { isPresented.wrappedValue = $0 != nil }
        ), onDismiss: onDismiss) { _ in
            content()
        }
    }
    
    public func sheet_<Item, SheetContent: View>(
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
    
    nonisolated public func onDismissAttempt_(_ action: @escaping () -> Void) -> some View {
        self.preference(key: OnDismissAttemptPreferenceKey.self, value: OnDismissAttemptClosure(closure: action))
    }
}

private struct OnDismissAttemptClosure: Equatable, @unchecked Sendable {
    let closure: () -> Void
    
    static func == (lhs: OnDismissAttemptClosure, rhs: OnDismissAttemptClosure) -> Bool { false }
}

private struct OnDismissAttemptPreferenceKey: PreferenceKey {
    static let defaultValue: OnDismissAttemptClosure? = nil
    
    static func reduce(value: inout OnDismissAttemptClosure?, nextValue: () -> OnDismissAttemptClosure?) {
        value = nextValue()
    }
}

private struct SheetModifier<Item, SheetContent: View>: ViewModifier {
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

private struct SheetContainer<Item, SheetContent: View>: UIViewControllerRepresentable {
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
        
        if let item = self.item, !isAlreadyPresented {
            let hostingController = UIHostingController(
                rootView: self.sheetContent(item)
                    .environment(\.dismissSheet, DismissSheetAction(dismiss: {
                        self.item = nil
                    }))
                    .onPreferenceChange(OnDismissAttemptPreferenceKey.self) { value in
                        MainActor.assumeIsolated{
                            context.coordinator.onDismissAttempt = value?.closure
                        }
                    }
            )
            hostingController.modalPresentationStyle = .automatic
            hostingController.presentationController?.delegate = context.coordinator
            uiViewController.present(hostingController, animated: true)
            uiViewController.presentingHostingController = hostingController
        } else if self.item == nil && isAlreadyPresented {
            uiViewController.presentingHostingController?.dismiss(animated: true)
            uiViewController.presentingHostingController = nil
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        let parent: SheetContainer
        
        var onDismissAttempt: (() -> Void)?
        
        init(parent: SheetContainer) {
            self.parent = parent
        }
        
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            self.parent.item = nil
            self.parent.onDismiss?()
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            self.onDismissAttempt?()
        }
    }
}

final private class SheetPresentationController: UIViewController {
    weak var presentingHostingController: UIViewController?
}
