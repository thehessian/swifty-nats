//
//  NatsClient+Connection.swift
//  SwiftyNats
//
//  Created by Ray Krow on 2/27/18.
//

import Foundation
import NIO
import Dispatch

extension NatsClient: NatsConnection {

    // MARK - Implement NatsConnection Protocol

    open func connect() throws {

        guard self.state != .connected else { return }

        self.dispatchGroup.enter()

        var thread: Thread?

        #if os(Linux)
        thread = Thread { self.setupConnection() }
        #else
        thread = Thread(target: self, selector: #selector(self.setupConnection), object: nil)
        #endif

        thread?.start()

        self.dispatchGroup.wait()

        if let error = self.connectionError {
            throw error
        }

        if self.server?.authRequired == true {
            try self.authenticateWithServer()
        }

        self.state = .connected
        self.fire(.connected)

    }

    open func disconnect() {

        try? self.channel?.close().wait()
        try? self.group.syncShutdownGracefully()
        self.state = .disconnected
        self.fire(.disconnected)
    }

    // MARK - Internal Methods

    internal func retryConnection() {

        self.fire(.reconnecting)
        var retryCount = 0

        if self.config.autoRetry {
            while retryCount < self.config.autoRetryMax {
                if let _ = try? self.connect() {
                    return
                }
                retryCount += 1
                usleep(UInt32(self.config.connectionRetryDelay))
            }
        }

        self.disconnect()
    }

    // MARK - Private Methods
    
    @objc
    fileprivate func setupConnection() {

        self.connectionError = nil

        // If we have a list of `connectUrls` in our current server
        // add them to the list of knownServers here so we can attempt
        // to connect to them as well
        var knownServers = self.urls
        if let otherServers = self.server?.connectUrls {
            knownServers.append(contentsOf: otherServers)
        }

        for server in knownServers {
            do {
                try self.openStream(to: server)
            } catch let e as NatsError {
                self.connectionError = e
                continue // to try next server
            } catch {
                self.connectionError = NatsConnectionError(error.localizedDescription)
                continue
            }
            self.connectedUrl = URL(string: server)
            break // If we got here then we connected successfully, break out of here and stop trying servers
        }

        self.dispatchGroup.leave()

        RunLoop.current.run()

    }

    fileprivate func openStream(to url: String) throws {

        guard let server = URL(string: url) else {
            throw NatsConnectionError("Invalid url provided: (\(url))")
        }

        guard let host = server.host, let port = server.port else {
            throw NatsConnectionError("Invalid url provided: (\(server.absoluteString))")
        }

        let bootstrap = ClientBootstrap(group: self.group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.add(handler: self)
            }

        var isInformed = false
        var hasErrored = false
        self.on([.informed, .error], autoOff: true) { e in
            switch e {
            case .informed:
                isInformed = true
                break
            case .error:
                hasErrored = true
                break
            default:
                break
            }

        }

        self.channel = try bootstrap.connect(host: host, port: port).wait()

        let timeout = 3 // seconds

        for _ in 0...timeout {
            if isInformed {
                break
            }
            if hasErrored {
                throw NatsConnectionError("Server returned an error while trying to connect")
            }
            sleep(1) // second
        }

        if !isInformed {
            throw NatsConnectionError("Server timedout. Waited \(timeout) seconds for info response but never got it")
        }

    }

    fileprivate func authenticateWithServer() throws {
        let config: [String: Any]
        if let user = self.connectedUrl?.user, let password = self.connectedUrl?.password {
            config = [
                "verbose": self.config.verbose,
                "pedantic": self.config.pedantic,
                "ssl_required": server!.sslRequired,
                "name": self.config.name,
                "lang": self.config.lang,
                "version": self.config.version,
                "user": user,
                "pass": password
            ]
        } else if let query = self.connectedUrl?.query?.components(separatedBy: "="), query.count == 2 {
            config = [
                "verbose": self.config.verbose,
                "pedantic": self.config.pedantic,
                "ssl_required": server!.sslRequired,
                "name": self.config.name,
                "lang": self.config.lang,
                "version": self.config.version,
                query.first! : query.last!,
            ]
        } else {
            throw NatsConnectionError("Server authentication requires url with basic authentication or a query parameter with the key-value pair to pass for authentication")
        }

        self.sendMessage(NatsMessage.connect(config: config), ignoreConnecionStatus: true)

    }

}
