import SwiftUI
import UserNotifications

@main
struct FairShareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(store.colorScheme)
                .task { store.start() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { store.resume() } }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let large = UIFont(name: "PlusJakartaSans-Bold", size: 32), let inline = UIFont(name: "PlusJakartaSans-SemiBold", size: 17) {
            let bar = UINavigationBar.appearance()
            bar.largeTitleTextAttributes = [.font: large]
            bar.titleTextAttributes = [.font: inline]
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack(alignment: .top) {
            Color.fsBackground.ignoresSafeArea()
            if store.hasOnboarded, let user = store.user {
                MainShell(user: user)
                    .id(user.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
            if let banner = store.banner {
                InAppBanner(banner: banner)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1000)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: store.hasOnboarded)
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: store.userId)
        .tint(Color.fsAccent)
        .font(.fs(17))
    }
}

struct InAppBanner: View {
    @Environment(AppStore.self) private var store
    let banner: AppStore.Banner

    var body: some View {
        let (icon, fg, bg): (String, Color, Color) = {
            switch banner.kind {
            case "approved", "budget": ("checkmark.circle.fill", .fsGreenText, .fsGreenSoft)
            case "rejected": ("xmark.circle.fill", .fsRedText, .fsRedSoft)
            case "submitted": ("paperplane.fill", .fsAmberText, .fsAmberSoft)
            default: ("bell.fill", .fsAccentText, .fsAccentSoft)
            }
        }()
        Button {
            store.pendingRoute = banner.ref
            withAnimation { store.banner = nil }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(fg)
                    .frame(width: 38, height: 38)
                    .background(bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(banner.title).font(.fs(15, .semibold)).foregroundStyle(Color.fsText)
                    Text(banner.body).font(.fs(13)).foregroundStyle(Color.fsText2).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle())
        .gesture(DragGesture().onEnded { v in if v.translation.height < -10 { withAnimation { store.banner = nil } } })
    }
}
