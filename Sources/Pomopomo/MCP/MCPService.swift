import Foundation
import Logging
import MCP

@MainActor
final class MCPService {
    private let coordinator: AppCoordinator
    private var serverTask: Task<Void, any Error>?

    static let port = 6390
    static let host = "127.0.0.1"
    static let endpoint = "/mcp"

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func start() {
        let coordinatorRef = CoordinatorRef(coordinator: coordinator)
        let port = Self.port
        let host = Self.host
        let endpoint = Self.endpoint

        serverTask = Task.detached {
            let logger = Logger(label: "pomopomo.mcp")

            let app = MCPHTTPApp(
                configuration: .init(
                    host: host,
                    port: port,
                    endpoint: endpoint
                ),
                serverFactory: { _, transport in
                    let server = Server(
                        name: "pomopomo",
                        version: "1.0.0",
                        capabilities: .init(tools: .init())
                    )
                    await configurePomodoroTools(on: server, coordinatorRef: coordinatorRef)
                    return server
                },
                logger: logger
            )

            try await app.start()
        }
    }

    func stop() {
        serverTask?.cancel()
        serverTask = nil
    }
}
