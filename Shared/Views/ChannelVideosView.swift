import Siesta
import SwiftUI

struct ChannelVideosView: View {
    let channel: Channel

    @State private var presentingShareSheet = false
    @State private var shareURL: URL?

    @StateObject private var store = Store<Channel>()

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.inNavigationView) private var inNavigationView

    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @EnvironmentObject<AccountsModel> private var accounts
    @EnvironmentObject<NavigationModel> private var navigation
    @EnvironmentObject<PlayerModel> private var player
    @EnvironmentObject<SubscriptionsModel> private var subscriptions

    @Namespace private var focusNamespace

    var videos: [ContentItem] {
        ContentItem.array(of: store.item?.videos ?? [])
    }

    var body: some View {
        #if os(iOS)
            if inNavigationView {
                content
            } else {
                PlayerControlsView {
                    content
                }
            }
        #else
            PlayerControlsView {
                content
            }
        #endif
    }

    var content: some View {
        let content = VStack {
            #if os(tvOS)
                HStack {
                    Text(navigationTitle)
                        .font(.title2)
                        .frame(alignment: .leading)

                    Spacer()

                    FavoriteButton(item: FavoriteItem(section: .channel(channel.id, channel.name)))
                        .labelStyle(.iconOnly)

                    if let subscribers = store.item?.subscriptionsString {
                        Text("**\(subscribers)** subscribers")
                            .foregroundColor(.secondary)
                    }

                    subscriptionToggleButton
                }
                .frame(maxWidth: .infinity)
            #endif

            #if os(iOS)
                VerticalCells(items: videos)
            #else
                if #available(macOS 12.0, *) {
                    VerticalCells(items: videos)
                        .prefersDefaultFocus(in: focusNamespace)
                } else {
                    VerticalCells(items: videos)
                }
            #endif
        }
        .environment(\.inChannelView, true)

        #if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ShareButton(
                        contentItem: contentItem,
                        presentingShareSheet: $presentingShareSheet,
                        shareURL: $shareURL
                    )
                }

                ToolbarItem {
                    HStack {
                        HStack(spacing: 3) {
                            Text("\(store.item?.subscriptionsString ?? "loading")")
                                .fontWeight(.bold)
                            Text(" subscribers")
                        }
                        .allowsTightening(true)
                        .foregroundColor(.secondary)
                        .opacity(store.item?.subscriptionsString != nil ? 1 : 0)

                        subscriptionToggleButton

                        FavoriteButton(item: FavoriteItem(section: .channel(channel.id, channel.name)))
                    }
                }
            }
        #endif
        #if os(iOS)
        .sheet(isPresented: $presentingShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
        #endif
        .onAppear {
            if store.item.isNil {
                resource.addObserver(store)
                resource.load()
            }
        }
        #if os(iOS)
        .navigationBarHidden(player.playerNavigationLinkActive)
        #endif
        .navigationTitle(navigationTitle)

        return Group {
            if #available(macOS 12.0, *) {
                content
                #if os(tvOS)
                .background(Color.background(scheme: colorScheme))
                #endif
                #if !os(iOS)
                .focusScope(focusNamespace)
                #endif
            } else {
                content
            }
        }
    }

    private var resource: Resource {
        let resource = accounts.api.channel(channel.id)
        resource.addObserver(store)

        return resource
    }

    private var subscriptionToggleButton: some View {
        Group {
            if accounts.app.supportsSubscriptions && accounts.signedIn {
                if subscriptions.isSubscribing(channel.id) {
                    Button("Unsubscribe") {
                        navigation.presentUnsubscribeAlert(channel)
                    }
                } else {
                    Button("Subscribe") {
                        subscriptions.subscribe(channel.id) {
                            navigation.sidebarSectionChanged.toggle()
                        }
                    }
                }
            }
        }
        .alert(isPresented: $navigation.presentingUnsubscribeAlert) {
            Alert(
                title: Text(
                    "Are you sure you want to unsubscribe from \(channel.name)?"
                ),
                primaryButton: .destructive(Text("Unsubscribe")) {
                    subscriptions.unsubscribe(channel.id)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var contentItem: ContentItem {
        ContentItem(channel: channel)
    }

    private var navigationTitle: String {
        store.item?.name ?? channel.name
    }
}
