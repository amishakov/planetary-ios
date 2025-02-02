//
//  Key.swift
//  
//
//  Created by Martin Dutra on 17/2/22.
//

import Foundation

/// The Key enum list the possible keys that a client can use to retrieve a value
public enum Key: String {
    /// PostHog Project API key
    case posthog

    /// Bugsnag Notifier API key
    case bugsnag

    /// Planetary Push token
    case push

    /// Authy token
    case authy

    /// Planetary Blob token
    case blob

    /// Planetary Pub token
    case pub

    /// Zendesk App ID
    case zendeskAppID

    /// Zendesk Client ID
    case zendeskClientID
}
