//
//  NotificationBox.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Combine
import SwiftUI

typealias NotificationModel = NotificationBox.Model
typealias NotificationSubject = PassthroughSubject<NotificationModel,Never>
typealias NotificationPublisher = AnyPublisher<NotificationModel,Never>

struct NotificationBox: View {
    struct Model: Equatable {
        let type: NotificationType
        let message: String
        
        init(type: NotificationType, message: String) {
            self.type = type
            self.message = message
        }
    }
    
    let type: NotificationType
    let content: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            type.image
                .frame(width: 25)
            Text(content)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 5)
        }.padding(15)
        .background(ThemeColors.white.clipShape(Capsule()))
    }
}

// MARK: - View Modifier
extension NotificationBox {
    struct NotificationModifier: ViewModifier {
        class ViewModel: ObservableObject {
            @Published var notification: NotificationModel?
            
            var notificationPublisher: NotificationPublisher
            var notificationCancellable: AnyCancellable?
            var cancelBag = CancelBag()
            
            init(notificationPublisher: NotificationPublisher) {
                self.notificationPublisher = notificationPublisher
            }
        }
        
        @ObservedObject private var viewModel: ViewModel
        
        init(notificationPublisher: NotificationPublisher) {
            viewModel = ViewModel(notificationPublisher: notificationPublisher)
            setupNotificationPipeline()
        }
        
        func body(content: Content) -> some View {
            ZStack {
                content
                VStack {
                    if let notificationModel = viewModel.notification {
                        Notification(model: notificationModel)
                    }
                    Spacer()
                }
            }
        }
        
        @ViewBuilder
        private func Notification(model: NotificationModel) -> some View {
            NotificationBox(type: model.type, content: model.message)
                .padding(.top, 20)
                .frame(maxWidth: 300)
                .transition(.move(edge: .top).combined(with: .opacity))
                .gesture(onSwipeUpGesture(hideNotification))
        }
        
        private func setupNotificationPipeline() {
            viewModel.notificationPublisher.sink { notification in
                show(notification: notification)
            }.store(in: viewModel.cancelBag)
        }
        
        private func onSwipeUpGesture(_ action: @escaping () -> Void) -> some Gesture {
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onEnded { value in
                    guard value.translation.height < 0 else { return }
                    hideNotification()
                }
        }
        
        private func show(notification: NotificationModel) {
            viewModel.notificationCancellable?.cancel()
            viewModel.notificationCancellable = nil
            
            withAnimation { viewModel.notification = notification }
            viewModel.notificationCancellable = Just(())
                .delay(for: .seconds(notification.type.timeToLive), scheduler: DispatchQueue.main)
                .sink { _ in
                    withAnimation { viewModel.notification = nil }
                }
        }
        
        private func hideNotification() {
            viewModel.notificationCancellable?.cancel()
            viewModel.notificationCancellable = nil
            withAnimation { viewModel.notification = nil }
        }
    }
}

extension View {
    func showNotification(_ publisher: NotificationSubject) -> some View {
        self.modifier(NotificationBox.NotificationModifier(notificationPublisher: publisher.eraseToAnyPublisher()))
            .environment(\.notificationPublisher, publisher)
    }
}

extension NotificationBox {
    enum NotificationType: CaseIterable {
        case success
        case failure
        case warning
        
        var image: some View {
            contentImage
                .resizable()
                .scaledToFit()
                .foregroundColor(imageColor)
        }
        
        var timeToLive: Double {
            TimeInterval(4.0)
        }
        
        private var contentImage: Image {
            switch self {
            case .success:
                return Image(systemName: "checkmark.circle.fill")
            case .failure:
                return Image(systemName: "xmark.octagon.fill")
            case .warning:
                return Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        
        private var imageColor: Color {
            switch self {
            case .success:
                return Color.green
            case .failure:
                return Color.red
            case .warning:
                return Color.yellow
            }
        }
    }
}
