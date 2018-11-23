//
//  NatsEventHandler.swift
//  SwiftyNats
//
//  Created by Ray Krow on 3/11/18.
//


internal struct NatsEventHandler {
    let listenerId: String
    let handler: (NatsEvent, String?) -> Void
    let autoOff: Bool
    init(lid: String, handler: @escaping (NatsEvent, String?) -> Void, autoOff: Bool = false) {
        self.listenerId = lid
        self.handler = handler
        self.autoOff = autoOff
    }
}
