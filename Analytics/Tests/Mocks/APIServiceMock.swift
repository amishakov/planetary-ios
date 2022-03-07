//
//  APIServiceMock.swift
//  
//
//  Created by Martin Dutra on 13/12/21.
//

@testable import Analytics
import Foundation

class APIServiceMock: APIService {

    var identified = false
    var forgot = false
    var tracked = false
    var optedIn = true
    var lastTrackedEvent = ""
    var enabled = true

    var isEnabled: Bool {
        enabled
    }

    func identify(identity: Identity) {
        identified = true
    }

    func optIn() {
        optedIn = true
    }

    func optOut() {
        optedIn = false
    }

    func forget() {
        forgot = true
    }

    func track(event: String, params: [String: Any]?) {
        tracked = true
        lastTrackedEvent = event
    }
}
