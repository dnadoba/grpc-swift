/*
 * Copyright 2020, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import EchoModel
@testable import GRPC
import Logging
import NIOCore
import NIOEmbedded
import NIOHTTP2
import XCTest

class ConnectionManagerTests: GRPCTestCase {
  private let loop = EmbeddedEventLoop()
  private let recorder = RecordingConnectivityDelegate()
  private var monitor: ConnectivityStateMonitor!

  private var defaultConfiguration: ClientConnection.Configuration {
    var configuration = ClientConnection.Configuration.default(
      target: .unixDomainSocket("/ignored"),
      eventLoopGroup: self.loop
    )

    configuration.connectionBackoff = nil
    configuration.backgroundActivityLogger = self.clientLogger

    return configuration
  }

  override func setUp() {
    super.setUp()
    self.monitor = ConnectivityStateMonitor(delegate: self.recorder, queue: nil)
  }

  override func tearDown() {
    XCTAssertNoThrow(try self.loop.syncShutdownGracefully())
    super.tearDown()
  }

  private func makeConnectionManager(
    configuration config: ClientConnection.Configuration? = nil,
    channelProvider: ((ConnectionManager, EventLoop) -> EventLoopFuture<Channel>)? = nil
  ) -> ConnectionManager {
    let configuration = config ?? self.defaultConfiguration

    return ConnectionManager(
      configuration: configuration,
      channelProvider: channelProvider.map { HookedChannelProvider($0) },
      connectivityDelegate: self.monitor,
      logger: self.logger
    )
  }

  private func waitForStateChange<Result>(
    from: ConnectivityState,
    to: ConnectivityState,
    timeout: DispatchTimeInterval = .seconds(1),
    file: StaticString = #filePath,
    line: UInt = #line,
    body: () throws -> Result
  ) rethrows -> Result {
    self.recorder.expectChange {
      XCTAssertEqual($0, Change(from: from, to: to), file: file, line: line)
    }
    let result = try body()
    self.recorder.waitForExpectedChanges(timeout: timeout, file: file, line: line)
    return result
  }

  private func waitForStateChanges<Result>(
    _ changes: [Change],
    timeout: DispatchTimeInterval = .seconds(1),
    file: StaticString = #filePath,
    line: UInt = #line,
    body: () throws -> Result
  ) rethrows -> Result {
    self.recorder.expectChanges(changes.count) {
      XCTAssertEqual($0, changes)
    }
    let result = try body()
    self.recorder.waitForExpectedChanges(timeout: timeout, file: file, line: line)
    return result
  }
}

extension ConnectionManagerTests {
  func testIdleShutdown() throws {
    let manager = self.makeConnectionManager()

    try self.waitForStateChange(from: .idle, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }

    // Getting a multiplexer should fail.
    let multiplexer = manager.getHTTP2Multiplexer()
    self.loop.run()
    XCTAssertThrowsError(try multiplexer.wait())
  }

  func testConnectFromIdleFailsWithNoReconnect() {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    let multiplexer: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let channel = manager.getHTTP2Multiplexer()
        self.loop.run()
        return channel
      }

    self.waitForStateChange(from: .connecting, to: .shutdown) {
      channelPromise.fail(DoomedChannelError())
    }

    XCTAssertThrowsError(try multiplexer.wait()) {
      XCTAssertTrue($0 is DoomedChannelError)
    }
  }

  func testConnectAndDisconnect() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    // Start the connection.
    self.waitForStateChange(from: .idle, to: .connecting) {
      _ = manager.getHTTP2Multiplexer()
      self.loop.run()
    }

    // Setup the real channel and activate it.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )
    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.addHandler(idleHandler).wait()
    channelPromise.succeed(channel)
    XCTAssertNoThrow(
      try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // Write a settings frame on the root stream; this'll make the channel 'ready'.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel.writeInbound(frame.encode()))
    }

    // Close the channel.
    try self.waitForStateChange(from: .ready, to: .shutdown) {
      // Now the channel should be available: shut it down.
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  func testConnectAndIdle() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    // Start the connection.
    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Setup the channel.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.addHandler(idleHandler).wait()
    channelPromise.succeed(channel)
    XCTAssertNoThrow(
      try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // Write a settings frame on the root stream; this'll make the channel 'ready'.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel.writeInbound(frame.encode()))
      // Wait for the multiplexer, it _must_ be ready now.
      XCTAssertNoThrow(try readyChannelMux.wait())
    }

    // Go idle. This will shutdown the channel.
    try self.waitForStateChange(from: .ready, to: .idle) {
      self.loop.advanceTime(by: .minutes(5))
      XCTAssertNoThrow(try channel.closeFuture.wait())
    }

    // Now shutdown.
    try self.waitForStateChange(from: .idle, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  /// Forwards only the first `channelInactive` call
  ///
  /// This is useful in tests where we intentionally mis-use the channels
  /// and call `fireChannelInactive` manually during the test but don't want
  /// teardown to cause precondition failures due to this unexpected behavior.
  class SwallowSecondInactiveHandler: ChannelInboundHandler {
    typealias InboundIn = HTTP2Frame
    typealias OutboundOut = HTTP2Frame

    private var seenAnInactive = false
    func channelInactive(context: ChannelHandlerContext) {
      if !self.seenAnInactive {
        self.seenAnInactive = true
        context.fireChannelInactive()
      }
    }
  }

  func testChannelInactiveBeforeActiveWithNoReconnect() throws {
    let channel = EmbeddedChannel(loop: self.loop)
    let channelPromise = self.loop.makePromise(of: Channel.self)

    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    // Start the connection.
    self.waitForStateChange(from: .idle, to: .connecting) {
      // Triggers the connect.
      _ = manager.getHTTP2Multiplexer()
      self.loop.run()
    }
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.syncOperations.addHandler(SwallowSecondInactiveHandler())
    try channel.pipeline.syncOperations.addHandler(h2handler)
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.syncOperations.addHandler(idleHandler)
    try channel.pipeline.syncOperations.addHandler(NIOCloseOnErrorHandler())
    channelPromise.succeed(channel)

    // Oops: wrong way around. We should tolerate this - just don't crash.
    channel.pipeline.fireChannelInactive()
    channel.pipeline.fireChannelActive()

    channel.embeddedEventLoop.run()
    try manager.shutdown(mode: .forceful).wait()
  }

  func testChannelInactiveBeforeActiveWillReconnect() throws {
    var channels = [EmbeddedChannel(loop: self.loop), EmbeddedChannel(loop: self.loop)]
    var channelPromises: [EventLoopPromise<Channel>] = [
      self.loop.makePromise(),
      self.loop.makePromise(),
    ]
    var channelFutures = Array(channelPromises.map { $0.futureResult })

    var configuration = self.defaultConfiguration
    configuration.connectionBackoff = .oneSecondFixed

    let manager = self.makeConnectionManager(configuration: configuration) { _, _ in
      return channelFutures.removeLast()
    }

    // Start the connection.
    self.waitForStateChange(from: .idle, to: .connecting) {
      // Triggers the connect.
      _ = manager.getHTTP2Multiplexer()
      self.loop.run()
    }

    // Setup the channel.
    let channel1 = channels.removeLast()
    let channel1Promise = channelPromises.removeLast()
    let idleHandler1 = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )
    let h2handler1 = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel1.eventLoop,
      streamDelegate: idleHandler1
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel1.pipeline.syncOperations.addHandler(SwallowSecondInactiveHandler())
    try channel1.pipeline.syncOperations.addHandler(h2handler1)
    idleHandler1.setMultiplexer(try h2handler1.syncMultiplexer())
    try channel1.pipeline.syncOperations.addHandler(idleHandler1)
    try channel1.pipeline.syncOperations.addHandler(NIOCloseOnErrorHandler())
    channel1Promise.succeed(channel1)
    // Oops: wrong way around. We should tolerate this.
    channel1.pipeline.fireChannelInactive()
    channel1.pipeline.fireChannelActive()

    // Start the next attempt.
    self.loop.advanceTime(by: .seconds(1))

    let channel2 = channels.removeLast()
    let channel2Promise = channelPromises.removeLast()
    let idleHandler2 = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )
    let h2handler2 = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel2.eventLoop,
      streamDelegate: idleHandler2
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }

    try channel2.pipeline.syncOperations.addHandler(SwallowSecondInactiveHandler())
    try channel2.pipeline.syncOperations.addHandler(h2handler2)
    idleHandler2.setMultiplexer(try h2handler2.syncMultiplexer())
    try channel2.pipeline.syncOperations.addHandler(idleHandler2)
    try channel2.pipeline.syncOperations.addHandler(NIOCloseOnErrorHandler())
    channel2Promise.succeed(channel2)

    try self.waitForStateChange(from: .connecting, to: .ready) {
      channel2.pipeline.fireChannelActive()
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel2.writeInbound(frame.encode()))
    }
  }

  func testIdleTimeoutWhenThereAreActiveStreams() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    // Start the connection.
    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Setup the channel.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.addHandler(idleHandler).wait()

    channelPromise.succeed(channel)
    XCTAssertNoThrow(
      try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // Write a settings frame on the root stream; this'll make the channel 'ready'.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel.writeInbound(frame.encode()))
      // Wait for the HTTP/2 stream multiplexer, it _must_ be ready now.
      XCTAssertNoThrow(try readyChannelMux.wait())
    }

    // "create" a stream; the details don't matter here.
    idleHandler.streamCreated(1, channel: channel)

    // Wait for the idle timeout: this should _not_ cause the channel to idle.
    self.loop.advanceTime(by: .minutes(5))

    // Now we're going to close the stream and wait for an idle timeout and then shutdown.
    self.waitForStateChange(from: .ready, to: .idle) {
      // Close the stream.
      idleHandler.streamClosed(1, channel: channel)
      // ... wait for the idle timeout,
      self.loop.advanceTime(by: .minutes(5))
    }

    // Now shutdown.
    try self.waitForStateChange(from: .idle, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  func testConnectAndThenBecomeInactive() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Setup the channel.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.addHandler(idleHandler).wait()
    channelPromise.succeed(channel)
    XCTAssertNoThrow(
      try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    try self.waitForStateChange(from: .connecting, to: .shutdown) {
      // Okay: now close the channel; the `readyChannel` future has not been completed yet.
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }

    // We failed to get a channel and we don't have reconnect configured: we should be shutdown and
    // the `readyChannelMux` should error.
    XCTAssertThrowsError(try readyChannelMux.wait())
  }

  func testConnectOnSecondAttempt() throws {
    let channelPromise: EventLoopPromise<Channel> = self.loop.makePromise()
    let channelFutures: [EventLoopFuture<Channel>] = [
      self.loop.makeFailedFuture(DoomedChannelError()),
      channelPromise.futureResult,
    ]
    var channelFutureIterator = channelFutures.makeIterator()

    var configuration = self.defaultConfiguration
    configuration.connectionBackoff = .oneSecondFixed

    let manager = self.makeConnectionManager(configuration: configuration) { _, _ in
      guard let next = channelFutureIterator.next() else {
        XCTFail("Too many channels requested")
        return self.loop.makeFailedFuture(DoomedChannelError())
      }
      return next
    }

    let readyChannelMux = self.waitForStateChanges([
      Change(from: .idle, to: .connecting),
      Change(from: .connecting, to: .transientFailure),
    ]) { () -> EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> in
      // Get a HTTP/2 stream multiplexer.
      let readyChannelMux = manager.getHTTP2Multiplexer()
      self.loop.run()
      return readyChannelMux
    }

    // Get a HTTP/2 stream mux from the manager - it is a future for the one we made earlier.
    let anotherReadyChannelMux = manager.getHTTP2Multiplexer()
    self.loop.run()

    // Move time forwards by a second to start the next connection attempt.
    self.waitForStateChange(from: .transientFailure, to: .connecting) {
      self.loop.advanceTime(by: .seconds(1))
    }

    // Setup the actual channel and complete the promise.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.addHandler(idleHandler).wait()
    channelPromise.succeed(channel)
    XCTAssertNoThrow(
      try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // Write a SETTINGS frame on the root stream.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel.writeInbound(frame.encode()))
    }

    // Wait for the HTTP/2 stream multiplexer, it _must_ be ready now.
    XCTAssertNoThrow(try readyChannelMux.wait())
    XCTAssertNoThrow(try anotherReadyChannelMux.wait())

    // Now shutdown.
    try self.waitForStateChange(from: .ready, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  func testShutdownWhileConnecting() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Now shutdown.
    let shutdownFuture: EventLoopFuture<Void> = self.waitForStateChange(
      from: .connecting,
      to: .shutdown
    ) {
      let shutdown = manager.shutdown()
      self.loop.run()
      return shutdown
    }

    // The multiplexer we were requesting should fail.
    XCTAssertThrowsError(try readyChannelMux.wait())

    // We still have our channel promise to fulfil: if it succeeds then it too should be closed.
    channelPromise.succeed(EmbeddedChannel(loop: self.loop))
    let channel = try channelPromise.futureResult.wait()
    self.loop.run()
    XCTAssertNoThrow(try channel.closeFuture.wait())
    XCTAssertNoThrow(try shutdownFuture.wait())
  }

  func testShutdownWhileTransientFailure() throws {
    var configuration = self.defaultConfiguration
    configuration.connectionBackoff = .oneSecondFixed

    let manager = self.makeConnectionManager(configuration: configuration) { _, _ in
      self.loop.makeFailedFuture(DoomedChannelError())
    }

    let readyChannelMux = self.waitForStateChanges([
      Change(from: .idle, to: .connecting),
      Change(from: .connecting, to: .transientFailure),
    ]) { () -> EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> in
      // Get a HTTP/2 stream multiplexer.
      let readyChannelMux = manager.getHTTP2Multiplexer()
      self.loop.run()
      return readyChannelMux
    }

    // Now shutdown.
    try self.waitForStateChange(from: .transientFailure, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }

    // The HTTP/2 stream mux we were requesting should fail.
    XCTAssertThrowsError(try readyChannelMux.wait())
  }

  func testShutdownWhileActive() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Prepare the channel
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.addHandler(idleHandler).wait()
    channelPromise.succeed(channel)
    XCTAssertNoThrow(
      try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // (No state change expected here: active is an internal state.)

    // Now shutdown.
    try self.waitForStateChange(from: .connecting, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }

    // The HTTP/2 stream multiplexer we were requesting should fail.
    XCTAssertThrowsError(try readyChannelMux.wait())
  }

  func testShutdownWhileShutdown() throws {
    let manager = self.makeConnectionManager()

    try self.waitForStateChange(from: .idle, to: .shutdown) {
      let firstShutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try firstShutdown.wait())
    }

    let secondShutdown = manager.shutdown()
    self.loop.run()
    XCTAssertNoThrow(try secondShutdown.wait())
  }

  func testTransientFailureWhileActive() throws {
    var configuration = self.defaultConfiguration
    configuration.connectionBackoff = .oneSecondFixed

    let channelPromise: EventLoopPromise<Channel> = self.loop.makePromise()
    let channelFutures: [EventLoopFuture<Channel>] = [
      channelPromise.futureResult,
      self.loop.makeFailedFuture(DoomedChannelError()),
    ]
    var channelFutureIterator = channelFutures.makeIterator()

    let manager = self.makeConnectionManager(configuration: configuration) { _, _ in
      guard let next = channelFutureIterator.next() else {
        XCTFail("Too many channels requested")
        return self.loop.makeFailedFuture(DoomedChannelError())
      }
      return next
    }

    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Prepare the channel
    let firstChannel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: firstChannel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try firstChannel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try firstChannel.pipeline.addHandler(idleHandler).wait()

    channelPromise.succeed(firstChannel)
    XCTAssertNoThrow(
      try firstChannel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // (No state change expected here: active is an internal state.)

    // Close the channel (simulate e.g. TLS handshake failed)
    try self.waitForStateChange(from: .connecting, to: .transientFailure) {
      XCTAssertNoThrow(try firstChannel.close().wait())
    }

    // Start connecting again.
    self.waitForStateChanges([
      Change(from: .transientFailure, to: .connecting),
      Change(from: .connecting, to: .transientFailure),
    ]) {
      self.loop.advanceTime(by: .seconds(1))
    }

    // Now shutdown
    try self.waitForStateChange(from: .transientFailure, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }

    // The channel never came up: it should be throw.
    XCTAssertThrowsError(try readyChannelMux.wait())
  }

  func testTransientFailureWhileReady() throws {
    var configuration = self.defaultConfiguration
    configuration.connectionBackoff = .oneSecondFixed

    let firstChannelPromise: EventLoopPromise<Channel> = self.loop.makePromise()
    let secondChannelPromise: EventLoopPromise<Channel> = self.loop.makePromise()
    let channelFutures: [EventLoopFuture<Channel>] = [
      firstChannelPromise.futureResult,
      secondChannelPromise.futureResult,
    ]
    var channelFutureIterator = channelFutures.makeIterator()

    let manager = self.makeConnectionManager(configuration: configuration) { _, _ in
      guard let next = channelFutureIterator.next() else {
        XCTFail("Too many channels requested")
        return self.loop.makeFailedFuture(DoomedChannelError())
      }
      return next
    }

    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Prepare the first channel
    let firstChannel = EmbeddedChannel(loop: self.loop)
    let firstIdleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )
    let firstH2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: firstChannel.eventLoop,
      streamDelegate: firstIdleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try firstChannel.pipeline.addHandler(firstH2handler).wait()
    firstIdleHandler.setMultiplexer(try firstH2handler.syncMultiplexer())
    try firstChannel.pipeline.addHandler(firstIdleHandler).wait()
    firstChannelPromise.succeed(firstChannel)
    XCTAssertNoThrow(
      try firstChannel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // Write a SETTINGS frame on the root stream.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try firstChannel.writeInbound(frame.encode()))
    }

    // Channel should now be ready.
    XCTAssertNoThrow(try readyChannelMux.wait())

    // Kill the first channel. But first ensure there's an active RPC, otherwise we'll idle.
    firstIdleHandler.streamCreated(1, channel: firstChannel)

    try self.waitForStateChange(from: .ready, to: .transientFailure) {
      XCTAssertNoThrow(try firstChannel.close().wait())
    }

    // Run to start connecting again.
    self.waitForStateChange(from: .transientFailure, to: .connecting) {
      self.loop.advanceTime(by: .seconds(1))
    }

    // Prepare the second channel
    let secondChannel = EmbeddedChannel(loop: self.loop)
    let secondIdleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )
    let secondH2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: secondChannel.eventLoop,
      streamDelegate: secondIdleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try secondChannel.pipeline.addHandler(secondH2handler).wait()
    secondIdleHandler.setMultiplexer(try secondH2handler.syncMultiplexer())
    try secondChannel.pipeline.addHandler(secondIdleHandler).wait()
    secondChannelPromise.succeed(secondChannel)
    XCTAssertNoThrow(
      try secondChannel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    // Write a SETTINGS frame on the root stream.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try secondChannel.writeInbound(frame.encode()))
    }

    // Now shutdown
    try self.waitForStateChange(from: .ready, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  func testGoAwayWhenReady() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(from: .idle, to: .connecting) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Setup the channel.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )

    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    try channel.pipeline.addHandler(idleHandler).wait()
    channelPromise.succeed(channel)
    XCTAssertNoThrow(
      try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored"))
        .wait()
    )

    try self.waitForStateChange(from: .connecting, to: .ready) {
      // Write a SETTINGS frame on the root stream.
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel.writeInbound(frame.encode()))
    }

    // Wait for the HTTP/2 stream multiplexer, it _must_ be ready now.
    XCTAssertNoThrow(try readyChannelMux.wait())

    // Send a GO_AWAY; the details don't matter. This will cause the connection to go idle and the
    // channel to close.
    try self.waitForStateChange(from: .ready, to: .idle) {
      let goAway = HTTP2Frame(
        streamID: .rootStream,
        payload: .goAway(lastStreamID: 1, errorCode: .noError, opaqueData: nil)
      )
      XCTAssertNoThrow(try channel.writeInbound(goAway.encode()))
      self.loop.run()
    }

    self.loop.run()
    XCTAssertNoThrow(try channel.closeFuture.wait())

    // Now shutdown
    try self.waitForStateChange(from: .idle, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  func testDoomedOptimisticChannelFromIdle() {
    var configuration = self.defaultConfiguration
    configuration.callStartBehavior = .fastFailure
    let manager = ConnectionManager(
      configuration: configuration,
      channelProvider: HookedChannelProvider { _, loop in
        return loop.makeFailedFuture(DoomedChannelError())
      },
      connectivityDelegate: nil,
      logger: self.logger
    )
    let candidate = manager.getHTTP2Multiplexer()
    self.loop.run()
    XCTAssertThrowsError(try candidate.wait())
  }

  func testDoomedOptimisticChannelFromConnecting() throws {
    var configuration = self.defaultConfiguration
    configuration.callStartBehavior = .fastFailure
    let promise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return promise.futureResult
    }

    self.waitForStateChange(from: .idle, to: .connecting) {
      // Trigger channel creation, and a connection attempt, we don't care about the HTTP/2 stream multiplexer.
      _ = manager.getHTTP2Multiplexer()
      self.loop.run()
    }

    // We're connecting: get an optimistic HTTP/2 stream multiplexer - this was selected in config.
    let optimisticChannelMux = manager.getHTTP2Multiplexer()
    self.loop.run()

    // Fail the promise.
    promise.fail(DoomedChannelError())

    XCTAssertThrowsError(try optimisticChannelMux.wait())
  }

  func testOptimisticChannelFromTransientFailure() throws {
    var configuration = self.defaultConfiguration
    configuration.callStartBehavior = .fastFailure
    configuration.connectionBackoff = ConnectionBackoff()

    let manager = self.makeConnectionManager(configuration: configuration) { _, _ in
      self.loop.makeFailedFuture(DoomedChannelError())
    }

    self.waitForStateChanges([
      Change(from: .idle, to: .connecting),
      Change(from: .connecting, to: .transientFailure),
    ]) {
      // Trigger channel creation, and a connection attempt, we don't care about the HTTP/2 stream multiplexer.
      _ = manager.getHTTP2Multiplexer()
      self.loop.run()
    }

    // Now we're sitting in transient failure. Get a HTTP/2 stream mux optimistically - selected in config.
    let optimisticChannelMux = manager.getHTTP2Multiplexer()
    self.loop.run()

    XCTAssertThrowsError(try optimisticChannelMux.wait()) { error in
      XCTAssertTrue(error is DoomedChannelError)
    }
  }

  func testOptimisticChannelFromShutdown() throws {
    var configuration = self.defaultConfiguration
    configuration.callStartBehavior = .fastFailure
    let manager = self.makeConnectionManager { _, _ in
      return self.loop.makeFailedFuture(DoomedChannelError())
    }

    let shutdown = manager.shutdown()
    self.loop.run()
    XCTAssertNoThrow(try shutdown.wait())

    // Get a channel optimistically. It'll fail, obviously.
    let channelMux = manager.getHTTP2Multiplexer()
    self.loop.run()
    XCTAssertThrowsError(try channelMux.wait())
  }

  func testForceIdleAfterInactive() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    // Start the connection.
    let readyChannelMux: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> =
      self
      .waitForStateChange(
        from: .idle,
        to: .connecting
      ) {
        let readyChannelMux = manager.getHTTP2Multiplexer()
        self.loop.run()
        return readyChannelMux
      }

    // Setup the real channel and activate it.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )
    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    XCTAssertNoThrow(try channel.pipeline.addHandler(idleHandler).wait())
    channelPromise.succeed(channel)
    self.loop.run()

    let connect = channel.connect(to: try SocketAddress(unixDomainSocketPath: "/ignored"))
    XCTAssertNoThrow(try connect.wait())

    // Write a SETTINGS frame on the root stream.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel.writeInbound(frame.encode()))
    }

    // The channel should now be ready.
    XCTAssertNoThrow(try readyChannelMux.wait())

    // Now drop the connection.
    try self.waitForStateChange(from: .ready, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  func testCloseWithoutActiveRPCs() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    // Start the connection.
    let readyChannelMux = self.waitForStateChange(
      from: .idle,
      to: .connecting
    ) { () -> EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> in
      let readyChannelMux = manager.getHTTP2Multiplexer()
      self.loop.run()
      return readyChannelMux
    }

    // Setup the actual channel and activate it.
    let channel = EmbeddedChannel(loop: self.loop)
    let idleHandler = GRPCIdleHandler(
      connectionManager: manager,
      idleTimeout: .minutes(5),
      keepalive: .init(),
      logger: self.logger
    )
    let h2handler = NIOHTTP2Handler(
      mode: .client,
      eventLoop: channel.eventLoop,
      streamDelegate: idleHandler
    ) { channel in
      channel.eventLoop.makeSucceededVoidFuture()
    }
    try channel.pipeline.addHandler(h2handler).wait()
    idleHandler.setMultiplexer(try h2handler.syncMultiplexer())
    XCTAssertNoThrow(try channel.pipeline.addHandler(idleHandler).wait())
    channelPromise.succeed(channel)
    self.loop.run()

    let connect = channel.connect(to: try SocketAddress(unixDomainSocketPath: "/ignored"))
    XCTAssertNoThrow(try connect.wait())

    // "ready" the connection.
    try self.waitForStateChange(from: .connecting, to: .ready) {
      let frame = HTTP2Frame(streamID: .rootStream, payload: .settings(.settings([])))
      XCTAssertNoThrow(try channel.writeInbound(frame.encode()))
    }

    // The HTTP/2 stream multiplexer should now be ready.
    XCTAssertNoThrow(try readyChannelMux.wait())

    // Close the channel. There are no active RPCs so we should idle rather than be in the transient
    // failure state.
    self.waitForStateChange(from: .ready, to: .idle) {
      channel.pipeline.fireChannelInactive()
    }
  }

  func testIdleErrorDoesNothing() throws {
    let manager = self.makeConnectionManager()

    // Dropping an error on this manager should be fine.
    manager.channelError(DoomedChannelError())

    // Shutting down is then safe.
    try self.waitForStateChange(from: .idle, to: .shutdown) {
      let shutdown = manager.shutdown()
      self.loop.run()
      XCTAssertNoThrow(try shutdown.wait())
    }
  }

  func testHTTP2Delegates() throws {
    let channel = EmbeddedChannel(loop: self.loop)
    defer {
      XCTAssertNoThrow(try channel.finish())
    }

    class HTTP2Delegate: ConnectionManagerHTTP2Delegate {
      var streamsOpened = 0
      var streamsClosed = 0
      var maxConcurrentStreams = 0

      func streamOpened(_ connectionManager: ConnectionManager) {
        self.streamsOpened += 1
      }

      func streamClosed(_ connectionManager: ConnectionManager) {
        self.streamsClosed += 1
      }

      func receivedSettingsMaxConcurrentStreams(
        _ connectionManager: ConnectionManager,
        maxConcurrentStreams: Int
      ) {
        self.maxConcurrentStreams = maxConcurrentStreams
      }
    }

    let http2 = HTTP2Delegate()

    let manager = ConnectionManager(
      eventLoop: self.loop,
      channelProvider: HookedChannelProvider { manager, eventLoop -> EventLoopFuture<Channel> in
        let idleHandler = GRPCIdleHandler(
          connectionManager: manager,
          idleTimeout: .minutes(5),
          keepalive: ClientConnectionKeepalive(),
          logger: self.logger
        )
        let h2Handler = NIOHTTP2Handler(
          mode: .client,
          eventLoop: channel.eventLoop,
          streamDelegate: idleHandler
        ) { channel in
          channel.eventLoop.makeSucceededVoidFuture()
        }
        try! channel.pipeline.syncOperations.addHandler(h2Handler)
        idleHandler.setMultiplexer(try! h2Handler.syncMultiplexer())

        // We're going to cheat a bit by not putting the multiplexer in the channel. This allows
        // us to just fire stream created/closed events into the channel.
        do {
          try channel.pipeline.syncOperations.addHandler(idleHandler)
        } catch {
          return eventLoop.makeFailedFuture(error)
        }

        return eventLoop.makeSucceededFuture(channel)
      },
      callStartBehavior: .waitsForConnectivity,
      connectionBackoff: ConnectionBackoff(),
      connectivityDelegate: nil,
      http2Delegate: http2,
      logger: self.logger
    )

    // Start connecting.
    let futureMultiplexer = manager.getHTTP2Multiplexer()
    self.loop.run()

    // Do the actual connecting.
    XCTAssertNoThrow(try channel.connect(to: SocketAddress(unixDomainSocketPath: "/ignored")))

    // The channel isn't ready until it's seen a SETTINGS frame.

    func makeSettingsFrame(maxConcurrentStreams: Int) -> HTTP2Frame {
      let settings = [HTTP2Setting(parameter: .maxConcurrentStreams, value: maxConcurrentStreams)]
      return HTTP2Frame(streamID: .rootStream, payload: .settings(.settings(settings)))
    }
    XCTAssertNoThrow(try channel.writeInbound(makeSettingsFrame(maxConcurrentStreams: 42).encode()))

    // We're ready now so the future multiplexer will resolve and we'll have seen an update to
    // max concurrent streams.
    XCTAssertNoThrow(try futureMultiplexer.wait())
    XCTAssertEqual(http2.maxConcurrentStreams, 42)

    XCTAssertNoThrow(try channel.writeInbound(makeSettingsFrame(maxConcurrentStreams: 13).encode()))
    XCTAssertEqual(http2.maxConcurrentStreams, 13)

    let streamDelegate = try channel.pipeline.handler(type: GRPCIdleHandler.self).wait()

    // Open some streams.
    for streamID in stride(from: HTTP2StreamID(1), to: HTTP2StreamID(9), by: 2) {
      streamDelegate.streamCreated(streamID, channel: channel)
    }

    // ... and then close them.
    for streamID in stride(from: HTTP2StreamID(1), to: HTTP2StreamID(9), by: 2) {
      streamDelegate.streamClosed(streamID, channel: channel)
    }

    XCTAssertEqual(http2.streamsOpened, 4)
    XCTAssertEqual(http2.streamsClosed, 4)
  }

  func testChannelErrorWhenConnecting() throws {
    let channelPromise = self.loop.makePromise(of: Channel.self)
    let manager = self.makeConnectionManager { _, _ in
      return channelPromise.futureResult
    }

    let multiplexer: EventLoopFuture<NIOHTTP2Handler.StreamMultiplexer> = self.waitForStateChange(
      from: .idle,
      to: .connecting
    ) {
      let channel = manager.getHTTP2Multiplexer()
      self.loop.run()
      return channel
    }

    self.waitForStateChange(from: .connecting, to: .shutdown) {
      manager.channelError(EventLoopError.shutdown)
    }

    XCTAssertThrowsError(try multiplexer.wait())
  }
}

internal struct Change: Hashable, CustomStringConvertible {
  var from: ConnectivityState
  var to: ConnectivityState

  var description: String {
    return "\(self.from) → \(self.to)"
  }
}

// Unchecked as all mutable state is modified from a serial queue.
extension RecordingConnectivityDelegate: @unchecked Sendable {}

internal class RecordingConnectivityDelegate: ConnectivityStateDelegate {
  private let serialQueue = DispatchQueue(label: "io.grpc.testing")
  private let semaphore = DispatchSemaphore(value: 0)
  private var expectation: Expectation = .noExpectation

  private let quiescingSemaphore = DispatchSemaphore(value: 0)

  private enum Expectation {
    /// We have no expectation of any changes. We'll just ignore any changes.
    case noExpectation

    /// We expect one change.
    case one((Change) -> Void)

    /// We expect 'count' changes.
    case some(count: Int, recorded: [Change], ([Change]) -> Void)

    var count: Int {
      switch self {
      case .noExpectation:
        return 0
      case .one:
        return 1
      case let .some(count, _, _):
        return count
      }
    }
  }

  func connectivityStateDidChange(
    from oldState: ConnectivityState,
    to newState: ConnectivityState
  ) {
    self.serialQueue.async {
      switch self.expectation {
      case let .one(verify):
        // We don't care about future changes.
        self.expectation = .noExpectation

        // Verify and notify.
        verify(Change(from: oldState, to: newState))
        self.semaphore.signal()

      case .some(let count, var recorded, let verify):
        recorded.append(Change(from: oldState, to: newState))
        if recorded.count == count {
          // We don't care about future changes.
          self.expectation = .noExpectation

          // Verify and notify.
          verify(recorded)
          self.semaphore.signal()
        } else {
          // Still need more responses.
          self.expectation = .some(count: count, recorded: recorded, verify)
        }

      case .noExpectation:
        // Ignore any changes.
        ()
      }
    }
  }

  func connectionStartedQuiescing() {
    self.serialQueue.async {
      self.quiescingSemaphore.signal()
    }
  }

  func expectChanges(_ count: Int, verify: @escaping ([Change]) -> Void) {
    self.serialQueue.async {
      self.expectation = .some(count: count, recorded: [], verify)
    }
  }

  func expectChange(verify: @escaping (Change) -> Void) {
    self.serialQueue.async {
      self.expectation = .one(verify)
    }
  }

  func waitForExpectedChanges(
    timeout: DispatchTimeInterval,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let result = self.semaphore.wait(timeout: .now() + timeout)
    switch result {
    case .success:
      ()
    case .timedOut:
      XCTFail(
        "Timed out before verifying \(self.expectation.count) change(s)",
        file: file,
        line: line
      )
    }
  }

  func waitForQuiescing(timeout: DispatchTimeInterval) {
    let result = self.quiescingSemaphore.wait(timeout: .now() + timeout)
    switch result {
    case .success:
      ()
    case .timedOut:
      XCTFail("Timed out waiting for connection to start quiescing")
    }
  }
}

extension ConnectionBackoff {
  fileprivate static let oneSecondFixed = ConnectionBackoff(
    initialBackoff: 1.0,
    maximumBackoff: 1.0,
    multiplier: 1.0,
    jitter: 0.0
  )
}

private struct DoomedChannelError: Error {}

internal struct HookedChannelProvider: ConnectionManagerChannelProvider {
  internal var provider: (ConnectionManager, EventLoop) -> EventLoopFuture<Channel>

  init(_ provider: @escaping (ConnectionManager, EventLoop) -> EventLoopFuture<Channel>) {
    self.provider = provider
  }

  func makeChannel(
    managedBy connectionManager: ConnectionManager,
    onEventLoop eventLoop: EventLoop,
    connectTimeout: TimeAmount?,
    logger: Logger
  ) -> EventLoopFuture<Channel> {
    return self.provider(connectionManager, eventLoop)
  }
}

extension ConnectionManager {
  // For backwards compatibility, to avoid large diffs in these tests.
  fileprivate func shutdown() -> EventLoopFuture<Void> {
    return self.shutdown(mode: .forceful)
  }
}
