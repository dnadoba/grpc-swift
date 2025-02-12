//
// DO NOT EDIT.
//
// Generated by the protocol buffer compiler.
// Source: benchmark_service.proto
//

//
// Copyright 2018, gRPC Authors All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import GRPC
import NIO
import NIOConcurrencyHelpers
import SwiftProtobuf


/// Usage: instantiate `Grpc_Testing_BenchmarkServiceClient`, then call methods of this protocol to make API calls.
public protocol Grpc_Testing_BenchmarkServiceClientProtocol: GRPCClient {
  var serviceName: String { get }
  var interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol? { get }

  func unaryCall(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func streamingCall(
    callOptions: CallOptions?,
    handler: @escaping (Grpc_Testing_SimpleResponse) -> Void
  ) -> BidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func streamingFromClient(
    callOptions: CallOptions?
  ) -> ClientStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func streamingFromServer(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions?,
    handler: @escaping (Grpc_Testing_SimpleResponse) -> Void
  ) -> ServerStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func streamingBothWays(
    callOptions: CallOptions?,
    handler: @escaping (Grpc_Testing_SimpleResponse) -> Void
  ) -> BidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>
}

extension Grpc_Testing_BenchmarkServiceClientProtocol {
  public var serviceName: String {
    return "grpc.testing.BenchmarkService"
  }

  /// One request followed by one response.
  /// The server returns the client payload as-is.
  ///
  /// - Parameters:
  ///   - request: Request to send to UnaryCall.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func unaryCall(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeUnaryCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.unaryCall.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeUnaryCallInterceptors() ?? []
    )
  }

  /// Repeated sequence of one request followed by one response.
  /// Should be called streaming ping-pong
  /// The server returns the client payload as-is on each response
  ///
  /// Callers should use the `send` method on the returned object to send messages
  /// to the server. The caller should send an `.end` after the final message has been sent.
  ///
  /// - Parameters:
  ///   - callOptions: Call options.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ClientStreamingCall` with futures for the metadata and status.
  public func streamingCall(
    callOptions: CallOptions? = nil,
    handler: @escaping (Grpc_Testing_SimpleResponse) -> Void
  ) -> BidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingCall.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingCallInterceptors() ?? [],
      handler: handler
    )
  }

  /// Single-sided unbounded streaming from client to server
  /// The server returns the client payload as-is once the client does WritesDone
  ///
  /// Callers should use the `send` method on the returned object to send messages
  /// to the server. The caller should send an `.end` after the final message has been sent.
  ///
  /// - Parameters:
  ///   - callOptions: Call options.
  /// - Returns: A `ClientStreamingCall` with futures for the metadata, status and response.
  public func streamingFromClient(
    callOptions: CallOptions? = nil
  ) -> ClientStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeClientStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromClient.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingFromClientInterceptors() ?? []
    )
  }

  /// Single-sided unbounded streaming from server to client
  /// The server repeatedly returns the client payload as-is
  ///
  /// - Parameters:
  ///   - request: Request to send to StreamingFromServer.
  ///   - callOptions: Call options.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ServerStreamingCall` with futures for the metadata and status.
  public func streamingFromServer(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions? = nil,
    handler: @escaping (Grpc_Testing_SimpleResponse) -> Void
  ) -> ServerStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeServerStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromServer.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingFromServerInterceptors() ?? [],
      handler: handler
    )
  }

  /// Two-sided unbounded streaming between server to client
  /// Both sides send the content of their own choice to the other
  ///
  /// Callers should use the `send` method on the returned object to send messages
  /// to the server. The caller should send an `.end` after the final message has been sent.
  ///
  /// - Parameters:
  ///   - callOptions: Call options.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ClientStreamingCall` with futures for the metadata and status.
  public func streamingBothWays(
    callOptions: CallOptions? = nil,
    handler: @escaping (Grpc_Testing_SimpleResponse) -> Void
  ) -> BidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingBothWays.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingBothWaysInterceptors() ?? [],
      handler: handler
    )
  }
}

#if compiler(>=5.6)
@available(*, deprecated)
extension Grpc_Testing_BenchmarkServiceClient: @unchecked Sendable {}
#endif // compiler(>=5.6)

@available(*, deprecated, renamed: "Grpc_Testing_BenchmarkServiceNIOClient")
public final class Grpc_Testing_BenchmarkServiceClient: Grpc_Testing_BenchmarkServiceClientProtocol {
  private let lock = Lock()
  private var _defaultCallOptions: CallOptions
  private var _interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol?
  public let channel: GRPCChannel
  public var defaultCallOptions: CallOptions {
    get { self.lock.withLock { return self._defaultCallOptions } }
    set { self.lock.withLockVoid { self._defaultCallOptions = newValue } }
  }
  public var interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol? {
    get { self.lock.withLock { return self._interceptors } }
    set { self.lock.withLockVoid { self._interceptors = newValue } }
  }

  /// Creates a client for the grpc.testing.BenchmarkService service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self._defaultCallOptions = defaultCallOptions
    self._interceptors = interceptors
  }
}

public struct Grpc_Testing_BenchmarkServiceNIOClient: Grpc_Testing_BenchmarkServiceClientProtocol {
  public var channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol?

  /// Creates a client for the grpc.testing.BenchmarkService service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

#if compiler(>=5.6)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol Grpc_Testing_BenchmarkServiceAsyncClientProtocol: GRPCClient {
  static var serviceDescriptor: GRPCServiceDescriptor { get }
  var interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol? { get }

  func makeUnaryCallCall(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions?
  ) -> GRPCAsyncUnaryCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func makeStreamingCallCall(
    callOptions: CallOptions?
  ) -> GRPCAsyncBidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func makeStreamingFromClientCall(
    callOptions: CallOptions?
  ) -> GRPCAsyncClientStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func makeStreamingFromServerCall(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions?
  ) -> GRPCAsyncServerStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>

  func makeStreamingBothWaysCall(
    callOptions: CallOptions?
  ) -> GRPCAsyncBidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Grpc_Testing_BenchmarkServiceAsyncClientProtocol {
  public static var serviceDescriptor: GRPCServiceDescriptor {
    return Grpc_Testing_BenchmarkServiceClientMetadata.serviceDescriptor
  }

  public var interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol? {
    return nil
  }

  public func makeUnaryCallCall(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncUnaryCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeAsyncUnaryCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.unaryCall.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeUnaryCallInterceptors() ?? []
    )
  }

  public func makeStreamingCallCall(
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncBidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeAsyncBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingCall.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingCallInterceptors() ?? []
    )
  }

  public func makeStreamingFromClientCall(
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncClientStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeAsyncClientStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromClient.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingFromClientInterceptors() ?? []
    )
  }

  public func makeStreamingFromServerCall(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncServerStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeAsyncServerStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromServer.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingFromServerInterceptors() ?? []
    )
  }

  public func makeStreamingBothWaysCall(
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncBidirectionalStreamingCall<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse> {
    return self.makeAsyncBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingBothWays.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingBothWaysInterceptors() ?? []
    )
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Grpc_Testing_BenchmarkServiceAsyncClientProtocol {
  public func unaryCall(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions? = nil
  ) async throws -> Grpc_Testing_SimpleResponse {
    return try await self.performAsyncUnaryCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.unaryCall.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeUnaryCallInterceptors() ?? []
    )
  }

  public func streamingCall<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Grpc_Testing_SimpleResponse> where RequestStream: Sequence, RequestStream.Element == Grpc_Testing_SimpleRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingCall.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingCallInterceptors() ?? []
    )
  }

  public func streamingCall<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Grpc_Testing_SimpleResponse> where RequestStream: AsyncSequence, RequestStream.Element == Grpc_Testing_SimpleRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingCall.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingCallInterceptors() ?? []
    )
  }

  public func streamingFromClient<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) async throws -> Grpc_Testing_SimpleResponse where RequestStream: Sequence, RequestStream.Element == Grpc_Testing_SimpleRequest {
    return try await self.performAsyncClientStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromClient.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingFromClientInterceptors() ?? []
    )
  }

  public func streamingFromClient<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) async throws -> Grpc_Testing_SimpleResponse where RequestStream: AsyncSequence, RequestStream.Element == Grpc_Testing_SimpleRequest {
    return try await self.performAsyncClientStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromClient.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingFromClientInterceptors() ?? []
    )
  }

  public func streamingFromServer(
    _ request: Grpc_Testing_SimpleRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Grpc_Testing_SimpleResponse> {
    return self.performAsyncServerStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromServer.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingFromServerInterceptors() ?? []
    )
  }

  public func streamingBothWays<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Grpc_Testing_SimpleResponse> where RequestStream: Sequence, RequestStream.Element == Grpc_Testing_SimpleRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingBothWays.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingBothWaysInterceptors() ?? []
    )
  }

  public func streamingBothWays<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Grpc_Testing_SimpleResponse> where RequestStream: AsyncSequence, RequestStream.Element == Grpc_Testing_SimpleRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingBothWays.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeStreamingBothWaysInterceptors() ?? []
    )
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct Grpc_Testing_BenchmarkServiceAsyncClient: Grpc_Testing_BenchmarkServiceAsyncClientProtocol {
  public var channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol?

  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

#endif // compiler(>=5.6)

public protocol Grpc_Testing_BenchmarkServiceClientInterceptorFactoryProtocol: GRPCSendable {

  /// - Returns: Interceptors to use when invoking 'unaryCall'.
  func makeUnaryCallInterceptors() -> [ClientInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when invoking 'streamingCall'.
  func makeStreamingCallInterceptors() -> [ClientInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when invoking 'streamingFromClient'.
  func makeStreamingFromClientInterceptors() -> [ClientInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when invoking 'streamingFromServer'.
  func makeStreamingFromServerInterceptors() -> [ClientInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when invoking 'streamingBothWays'.
  func makeStreamingBothWaysInterceptors() -> [ClientInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]
}

public enum Grpc_Testing_BenchmarkServiceClientMetadata {
  public static let serviceDescriptor = GRPCServiceDescriptor(
    name: "BenchmarkService",
    fullName: "grpc.testing.BenchmarkService",
    methods: [
      Grpc_Testing_BenchmarkServiceClientMetadata.Methods.unaryCall,
      Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingCall,
      Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromClient,
      Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingFromServer,
      Grpc_Testing_BenchmarkServiceClientMetadata.Methods.streamingBothWays,
    ]
  )

  public enum Methods {
    public static let unaryCall = GRPCMethodDescriptor(
      name: "UnaryCall",
      path: "/grpc.testing.BenchmarkService/UnaryCall",
      type: GRPCCallType.unary
    )

    public static let streamingCall = GRPCMethodDescriptor(
      name: "StreamingCall",
      path: "/grpc.testing.BenchmarkService/StreamingCall",
      type: GRPCCallType.bidirectionalStreaming
    )

    public static let streamingFromClient = GRPCMethodDescriptor(
      name: "StreamingFromClient",
      path: "/grpc.testing.BenchmarkService/StreamingFromClient",
      type: GRPCCallType.clientStreaming
    )

    public static let streamingFromServer = GRPCMethodDescriptor(
      name: "StreamingFromServer",
      path: "/grpc.testing.BenchmarkService/StreamingFromServer",
      type: GRPCCallType.serverStreaming
    )

    public static let streamingBothWays = GRPCMethodDescriptor(
      name: "StreamingBothWays",
      path: "/grpc.testing.BenchmarkService/StreamingBothWays",
      type: GRPCCallType.bidirectionalStreaming
    )
  }
}

/// To build a server, implement a class that conforms to this protocol.
public protocol Grpc_Testing_BenchmarkServiceProvider: CallHandlerProvider {
  var interceptors: Grpc_Testing_BenchmarkServiceServerInterceptorFactoryProtocol? { get }

  /// One request followed by one response.
  /// The server returns the client payload as-is.
  func unaryCall(request: Grpc_Testing_SimpleRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Grpc_Testing_SimpleResponse>

  /// Repeated sequence of one request followed by one response.
  /// Should be called streaming ping-pong
  /// The server returns the client payload as-is on each response
  func streamingCall(context: StreamingResponseCallContext<Grpc_Testing_SimpleResponse>) -> EventLoopFuture<(StreamEvent<Grpc_Testing_SimpleRequest>) -> Void>

  /// Single-sided unbounded streaming from client to server
  /// The server returns the client payload as-is once the client does WritesDone
  func streamingFromClient(context: UnaryResponseCallContext<Grpc_Testing_SimpleResponse>) -> EventLoopFuture<(StreamEvent<Grpc_Testing_SimpleRequest>) -> Void>

  /// Single-sided unbounded streaming from server to client
  /// The server repeatedly returns the client payload as-is
  func streamingFromServer(request: Grpc_Testing_SimpleRequest, context: StreamingResponseCallContext<Grpc_Testing_SimpleResponse>) -> EventLoopFuture<GRPCStatus>

  /// Two-sided unbounded streaming between server to client
  /// Both sides send the content of their own choice to the other
  func streamingBothWays(context: StreamingResponseCallContext<Grpc_Testing_SimpleResponse>) -> EventLoopFuture<(StreamEvent<Grpc_Testing_SimpleRequest>) -> Void>
}

extension Grpc_Testing_BenchmarkServiceProvider {
  public var serviceName: Substring {
    return Grpc_Testing_BenchmarkServiceServerMetadata.serviceDescriptor.fullName[...]
  }

  /// Determines, calls and returns the appropriate request handler, depending on the request's method.
  /// Returns nil for methods not handled by this service.
  public func handle(
    method name: Substring,
    context: CallHandlerContext
  ) -> GRPCServerHandlerProtocol? {
    switch name {
    case "UnaryCall":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeUnaryCallInterceptors() ?? [],
        userFunction: self.unaryCall(request:context:)
      )

    case "StreamingCall":
      return BidirectionalStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingCallInterceptors() ?? [],
        observerFactory: self.streamingCall(context:)
      )

    case "StreamingFromClient":
      return ClientStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingFromClientInterceptors() ?? [],
        observerFactory: self.streamingFromClient(context:)
      )

    case "StreamingFromServer":
      return ServerStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingFromServerInterceptors() ?? [],
        userFunction: self.streamingFromServer(request:context:)
      )

    case "StreamingBothWays":
      return BidirectionalStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingBothWaysInterceptors() ?? [],
        observerFactory: self.streamingBothWays(context:)
      )

    default:
      return nil
    }
  }
}

#if compiler(>=5.6)

/// To implement a server, implement an object which conforms to this protocol.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol Grpc_Testing_BenchmarkServiceAsyncProvider: CallHandlerProvider {
  static var serviceDescriptor: GRPCServiceDescriptor { get }
  var interceptors: Grpc_Testing_BenchmarkServiceServerInterceptorFactoryProtocol? { get }

  /// One request followed by one response.
  /// The server returns the client payload as-is.
  @Sendable func unaryCall(
    request: Grpc_Testing_SimpleRequest,
    context: GRPCAsyncServerCallContext
  ) async throws -> Grpc_Testing_SimpleResponse

  /// Repeated sequence of one request followed by one response.
  /// Should be called streaming ping-pong
  /// The server returns the client payload as-is on each response
  @Sendable func streamingCall(
    requestStream: GRPCAsyncRequestStream<Grpc_Testing_SimpleRequest>,
    responseStream: GRPCAsyncResponseStreamWriter<Grpc_Testing_SimpleResponse>,
    context: GRPCAsyncServerCallContext
  ) async throws

  /// Single-sided unbounded streaming from client to server
  /// The server returns the client payload as-is once the client does WritesDone
  @Sendable func streamingFromClient(
    requestStream: GRPCAsyncRequestStream<Grpc_Testing_SimpleRequest>,
    context: GRPCAsyncServerCallContext
  ) async throws -> Grpc_Testing_SimpleResponse

  /// Single-sided unbounded streaming from server to client
  /// The server repeatedly returns the client payload as-is
  @Sendable func streamingFromServer(
    request: Grpc_Testing_SimpleRequest,
    responseStream: GRPCAsyncResponseStreamWriter<Grpc_Testing_SimpleResponse>,
    context: GRPCAsyncServerCallContext
  ) async throws

  /// Two-sided unbounded streaming between server to client
  /// Both sides send the content of their own choice to the other
  @Sendable func streamingBothWays(
    requestStream: GRPCAsyncRequestStream<Grpc_Testing_SimpleRequest>,
    responseStream: GRPCAsyncResponseStreamWriter<Grpc_Testing_SimpleResponse>,
    context: GRPCAsyncServerCallContext
  ) async throws
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Grpc_Testing_BenchmarkServiceAsyncProvider {
  public static var serviceDescriptor: GRPCServiceDescriptor {
    return Grpc_Testing_BenchmarkServiceServerMetadata.serviceDescriptor
  }

  public var serviceName: Substring {
    return Grpc_Testing_BenchmarkServiceServerMetadata.serviceDescriptor.fullName[...]
  }

  public var interceptors: Grpc_Testing_BenchmarkServiceServerInterceptorFactoryProtocol? {
    return nil
  }

  public func handle(
    method name: Substring,
    context: CallHandlerContext
  ) -> GRPCServerHandlerProtocol? {
    switch name {
    case "UnaryCall":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeUnaryCallInterceptors() ?? [],
        wrapping: self.unaryCall(request:context:)
      )

    case "StreamingCall":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingCallInterceptors() ?? [],
        wrapping: self.streamingCall(requestStream:responseStream:context:)
      )

    case "StreamingFromClient":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingFromClientInterceptors() ?? [],
        wrapping: self.streamingFromClient(requestStream:context:)
      )

    case "StreamingFromServer":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingFromServerInterceptors() ?? [],
        wrapping: self.streamingFromServer(request:responseStream:context:)
      )

    case "StreamingBothWays":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Grpc_Testing_SimpleRequest>(),
        responseSerializer: ProtobufSerializer<Grpc_Testing_SimpleResponse>(),
        interceptors: self.interceptors?.makeStreamingBothWaysInterceptors() ?? [],
        wrapping: self.streamingBothWays(requestStream:responseStream:context:)
      )

    default:
      return nil
    }
  }
}

#endif // compiler(>=5.6)

public protocol Grpc_Testing_BenchmarkServiceServerInterceptorFactoryProtocol {

  /// - Returns: Interceptors to use when handling 'unaryCall'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeUnaryCallInterceptors() -> [ServerInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when handling 'streamingCall'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeStreamingCallInterceptors() -> [ServerInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when handling 'streamingFromClient'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeStreamingFromClientInterceptors() -> [ServerInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when handling 'streamingFromServer'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeStreamingFromServerInterceptors() -> [ServerInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]

  /// - Returns: Interceptors to use when handling 'streamingBothWays'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeStreamingBothWaysInterceptors() -> [ServerInterceptor<Grpc_Testing_SimpleRequest, Grpc_Testing_SimpleResponse>]
}

public enum Grpc_Testing_BenchmarkServiceServerMetadata {
  public static let serviceDescriptor = GRPCServiceDescriptor(
    name: "BenchmarkService",
    fullName: "grpc.testing.BenchmarkService",
    methods: [
      Grpc_Testing_BenchmarkServiceServerMetadata.Methods.unaryCall,
      Grpc_Testing_BenchmarkServiceServerMetadata.Methods.streamingCall,
      Grpc_Testing_BenchmarkServiceServerMetadata.Methods.streamingFromClient,
      Grpc_Testing_BenchmarkServiceServerMetadata.Methods.streamingFromServer,
      Grpc_Testing_BenchmarkServiceServerMetadata.Methods.streamingBothWays,
    ]
  )

  public enum Methods {
    public static let unaryCall = GRPCMethodDescriptor(
      name: "UnaryCall",
      path: "/grpc.testing.BenchmarkService/UnaryCall",
      type: GRPCCallType.unary
    )

    public static let streamingCall = GRPCMethodDescriptor(
      name: "StreamingCall",
      path: "/grpc.testing.BenchmarkService/StreamingCall",
      type: GRPCCallType.bidirectionalStreaming
    )

    public static let streamingFromClient = GRPCMethodDescriptor(
      name: "StreamingFromClient",
      path: "/grpc.testing.BenchmarkService/StreamingFromClient",
      type: GRPCCallType.clientStreaming
    )

    public static let streamingFromServer = GRPCMethodDescriptor(
      name: "StreamingFromServer",
      path: "/grpc.testing.BenchmarkService/StreamingFromServer",
      type: GRPCCallType.serverStreaming
    )

    public static let streamingBothWays = GRPCMethodDescriptor(
      name: "StreamingBothWays",
      path: "/grpc.testing.BenchmarkService/StreamingBothWays",
      type: GRPCCallType.bidirectionalStreaming
    )
  }
}
