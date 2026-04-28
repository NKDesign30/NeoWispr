import Foundation
import XCTest
@testable import NeoWispr

final class LLMPostProcessorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("groq", forKey: AppSettings.llmProvider)
        UserDefaults.standard.set(LLMPostProcessor.groqDefaultModel, forKey: AppSettings.groqModel)
    }

    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        UserDefaults.standard.removeObject(forKey: AppSettings.llmProvider)
        UserDefaults.standard.removeObject(forKey: AppSettings.groqModel)
        UserDefaults.standard.removeObject(forKey: AppSettings.customPrompt)
        UserDefaults.standard.removeObject(forKey: AppSettings.removeFillerWords)
        super.tearDown()
    }

    func testGroqSendsBearerHeaderAndCleansSuccessfulText() async throws {
        var authorizationHeader: String?
        URLProtocolStub.requestHandler = { request in
            authorizationHeader = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"\"Hallo Welt\""}}]}"#.utf8)
            return (response, data)
        }

        let processor = LLMPostProcessor(
            urlSession: makeURLSession(),
            groqEndpoint: URL(string: "https://groq.test/chat")!,
            groqAPIKeyProvider: { "test-key" }
        )

        let result = try await processor.process(text: "ähm hallo welt", style: .none)

        XCTAssertEqual(authorizationHeader, "Bearer test-key")
        XCTAssertEqual(result, "Hallo Welt")
    }

    func testGroq401MapsToProviderNotAvailable() async {
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"error":{"message":"invalid key","type":"authentication_error"}}"#.utf8)
            return (response, data)
        }

        let processor = LLMPostProcessor(
            urlSession: makeURLSession(),
            groqEndpoint: URL(string: "https://groq.test/chat")!,
            groqAPIKeyProvider: { "bad-key" }
        )

        do {
            _ = try await processor.process(text: "Hallo", style: .none)
            XCTFail("Expected provider error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Groq API-Key ungültig"))
        }
    }

    func testGroq429MapsToProcessFailed() async {
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"error":{"message":"rate limit","type":"rate_limit_error"}}"#.utf8)
            return (response, data)
        }

        let processor = LLMPostProcessor(
            urlSession: makeURLSession(),
            groqEndpoint: URL(string: "https://groq.test/chat")!,
            groqAPIKeyProvider: { "test-key" }
        )

        do {
            _ = try await processor.process(text: "Hallo", style: .none)
            XCTFail("Expected rate-limit error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Groq Rate-Limit erreicht"))
        }
    }

    private func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class URLProtocolStub: URLProtocol {

    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
