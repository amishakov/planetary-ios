//
//  ConnectedPeersCoordinator.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Combine
import Logger
import Analytics

/// A model for `ConnectedPeerListView`
protocol ConnectedPeerListViewModel: ObservableObject {
    var peers: [PeerConnectionInfo]? { get }
    var recentlyDownloadedPostCount: Int? { get }
    var recentlyDownloadedPostDuration: Int? { get }
    var connectedPeersCount: Int? { get set }
    func peerTapped(_: PeerConnectionInfo)
    func viewDidAppear()
    func viewDidDisappear()
}

/// A Router that can change scenes for `ConnectedPeerListCoordinator`
protocol ConnectedPeerListRouter: AlertRouter {
    func showProfile(for identity: Identity)
}

/// An enumeration of the errors produced by `ConnectedPeerListCoordinator`
enum ConnectedPeerListError: LocalizedError {

    case identityNotFound
    
    var errorDescription: String? {
        switch self {
        case .identityNotFound:
            return Text.identityNotFound.text
        }
    }
}

/// A Coordinator for the `ConnectedPeerListView`, providing the view model to the view and delegating user
/// actions generated by the view.
class ConnectedPeerListCoordinator: ConnectedPeerListViewModel {
    
    // MARK: - Public Properties
    
    /// The list of connected peers.
    @Published var peers: [PeerConnectionInfo]?
    
    /// The number of posts we have downloaded recently.
    @Published var recentlyDownloadedPostCount: Int?
    
    /// The definition of "recently" for `recentlyDownloadedPostCount` in minutes.
    @Published var recentlyDownloadedPostDuration: Int?
    
    /// The number of peers connected right now.
    var connectedPeersCount: Int? {
        get {
            peers?.filter({ $0.isActive }).count
        }
        set {
            // We just need this to use `Binding`
            return
        }
    }
    
    // MARK: - Private Properties
    
    private var router: ConnectedPeerListRouter
    
    private var statisticsService: BotStatisticsService
    
    private var cancellables = [AnyCancellable]()
        
    private var bot: Bot
    
    // MARK: - Lifecycle
        
    init(bot: Bot, statisticsService: BotStatisticsService, router: ConnectedPeerListRouter) {
        self.bot = bot
        self.statisticsService = statisticsService
        self.router = router
    }
    
    func viewDidAppear() {
        Task {
            await subscribeToBotStatistics()
        }
    }
    
    func viewDidDisappear() {
        unsubscribeFromBotStatistics()
    }
        
    private func subscribeToBotStatistics() async {
        let statisticsPublisher = await statisticsService.subscribe()
        
        // Wire up peers array to the statisticsService
        statisticsPublisher
            .map { $0.peer }
            .asyncFlatMap { peerStatistics in
                await self.peerConnectionInfo(from: peerStatistics)
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.peers = $0
            }
            .store(in: &self.cancellables)
        
        // Wire up recentlyDownloadedPostCount and recentlyDownloadedDuration to the statistics
        statisticsPublisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: { statistics in
                self.recentlyDownloadedPostCount = statistics.recentlyDownloadedPostCount
                self.recentlyDownloadedPostDuration = statistics.recentlyDownloadedPostDuration
            })
            .store(in: &cancellables)
    }
    
    private func unsubscribeFromBotStatistics() {
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - User Actions
    
    func peerTapped(_ connectionInfo: PeerConnectionInfo) {
        // Only supporting ed25519 keys for now.
        // See https://github.com/planetary-social/planetary-ios/issues/400
        let identity = connectionInfo.identity ?? "@\(connectionInfo.id).ed25519"
        Analytics.shared.trackDidTapButton(buttonName: "show_connected_peer_profile")
        router.showProfile(for: identity)
    }    
    
    // MARK: - Helpers
    
    /// This function cross references the raw `PeerStatistics` data with `About` messages in the `ViewDatabase` to
    /// produce `[PeerConnectionInfo]`.
    ///
    /// Note: This function will only discover `About` messages for ed25519 feeds right now. Adding support for
    /// other feed formats is tracked in https://github.com/planetary-social/planetary-ios/issues/400
    private func peerConnectionInfo(from peerStatistics: PeerStatistics) async -> [PeerConnectionInfo] {
        
        // Map old peers in as inactive
        var peerConnectionInfo = (peers ?? []).map { (oldPeer: PeerConnectionInfo) -> PeerConnectionInfo in
            var newPeer = oldPeer
            newPeer.isActive = false
            return newPeer
        }
        
        // Walk through peer statistics and create new connection info
        for (_, publicKey) in peerStatistics.currentOpen {
            peerConnectionInfo.removeAll(where: { $0.id == publicKey })
            // Only supporting ed25519 keys for now.
            // See https://github.com/planetary-social/planetary-ios/issues/400
            let identity = "@\(publicKey).ed25519"
            
            let about = try? await bot.about(identity: identity)
            
            guard let about = about else {
                peerConnectionInfo.append(PeerConnectionInfo(id: publicKey, name: publicKey))
                continue
            }
            
            peerConnectionInfo.append(PeerConnectionInfo(about: about))
        }
        
        return peerConnectionInfo.sorted { lhs, rhs in
            guard lhs.isActive == rhs.isActive else {
                return lhs.isActive
            }
            
            return lhs.name ?? "" < rhs.name ?? ""
        }
    }
}
