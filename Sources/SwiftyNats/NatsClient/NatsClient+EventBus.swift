//
//  NatsClient+EventBus.swift
//  SwiftyNats
//
//  Created by Ray Krow on 2/27/18.
//

extension NatsClient: NatsEventBus {
    
    // MARK - Implement NatsEvents Protocol
    
    @discardableResult
    open func on(_ events: [NatsEvent], _ handler: @escaping (NatsEvent, String?) -> Void) -> String {
        
        return self.addListeners(for: events, using: handler)

    }
    
    @discardableResult
    open func on(_ event: NatsEvent, _ handler: @escaping (NatsEvent, String?) -> Void) -> String {
        
        return self.addListeners(for: [event], using: handler)
        
    }
    
    @discardableResult
    open func on(_ event: NatsEvent, autoOff: Bool, _ handler: @escaping (NatsEvent, String?) -> Void) -> String {
        
        return self.addListeners(for: [event], using: handler, autoOff)
        
    }
    
    @discardableResult
    open func on(_ events: [NatsEvent], autoOff: Bool, _ handler: @escaping (NatsEvent, String?) -> Void) -> String {
        
        return self.addListeners(for: events, using: handler, autoOff)
        
    }
    
    open func off(_ id: String) {
        
        self.removeListener(id)
        
    }
    
    // MARK - Implement internal methods
    
    internal func fire(_ event: NatsEvent, message: String?) {
        
        guard let handlerStore = self.eventHandlerStore[event] else { return }

        handlerStore.forEach {
            $0.handler(event, message)
            if $0.autoOff {
                removeListener($0.listenerId)
            }
        }
        
    }
    
    // MARK - Implement private methods
    
    fileprivate func addListeners(for events: [NatsEvent], using handler: @escaping (NatsEvent, String?) -> Void, _ autoOff: Bool = false) -> String {
        
        let id = String.hash()
        
        for event in events {
            if self.eventHandlerStore[event] == nil {
                self.eventHandlerStore[event] = []
            }
            self.eventHandlerStore[event]?.append(NatsEventHandler(lid: id, handler: handler, autoOff: autoOff))
        }

        return id
        
    }
    
    fileprivate func removeListener(_ id: String) {
        
        for event in NatsEvent.all {
            
            let handlerStore = self.eventHandlerStore[event]
            if let store = handlerStore {
                self.eventHandlerStore[event] = store.filter { $0.listenerId != id }
            }
            
        }
        
    }
    
}
