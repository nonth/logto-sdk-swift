import Logto
@testable import LogtoClient
import LogtoMock
import XCTest

class LogtoAuthSessionSuccessMock: LogtoAuthSession {
    override func start() async throws -> LogtoCore.CodeTokenResponse {
        try! JSONDecoder().decode(LogtoCore.CodeTokenResponse.self, from: Data("""
            {
                "accessToken": "foo",
                "refreshToken": "bar",
                "idToken": "baz",
                "scope": "openid offline_access",
                "expiresIn": 300
            }
        """.utf8))
    }
}

class LogtoAuthSessionFailureMock: LogtoAuthSession {
    override func start() async throws -> LogtoCore.CodeTokenResponse {
        throw LogtoAuthSession.Errors.SignIn(type: .unknownError, innerError: nil)
    }
}

class LogtoAuthSessionExtraParamsMock: LogtoAuthSession {
    override func start() async throws -> LogtoCore.CodeTokenResponse {
        // Verify that extraParams were set correctly
        XCTAssertNotNil(extraParams)
        XCTAssertEqual(extraParams?["tenant_id"], "test_tenant")
        XCTAssertEqual(extraParams?["ui_locales"], "en-US")

        return try! JSONDecoder().decode(LogtoCore.CodeTokenResponse.self, from: Data("""
            {
                "accessToken": "foo",
                "refreshToken": "bar",
                "idToken": "baz",
                "scope": "openid offline_access",
                "expiresIn": 300
            }
        """.utf8))
    }
}

extension LogtoClientTests {
    func testSignInWithExtraParams() async throws {
        let client = buildClient(withToken: true)

        do {
            try await client.signInWithBrowser(
                authSessionType: LogtoAuthSessionExtraParamsMock.self,
                redirectUri: "io.logto.dev://callback",
                extraParams: ["tenant_id": "test_tenant", "ui_locales": "en-US"]
            )
        } catch let error as LogtoClientErrors.JwkSet {
            // Expected error since we don't have JWKS endpoint in the mock
            XCTAssertEqual(error.type, .unableToFetchJwkSet)
            return
        }

        XCTFail()
    }

    func testSignInUnableToFetchJwkSet() async throws {
        let client = buildClient(withToken: true)

        do {
            try await client.signInWithBrowser(
                authSessionType: LogtoAuthSessionSuccessMock.self,
                redirectUri: "io.logto.dev://callback"
            )
        } catch let error as LogtoClientErrors.JwkSet {
            XCTAssertEqual(error.type, .unableToFetchJwkSet)
            XCTAssertEqual(client.idToken, initialIdToken)
            return
        }

        XCTFail()
    }

    func testSignInUnableToConstructRedirectUri() async throws {
        let client = buildClient()

        do {
            try await client.signInWithBrowser(redirectUri: "")
        } catch let error as LogtoClientErrors.SignIn {
            XCTAssertEqual(error.type, .unableToConstructRedirectUri)
            return
        }

        XCTFail()
    }

    func testSignInUnableToFetchOidcConfig() async throws {
        let client = buildClient(withOidcEndpoint: "/bad")

        do {
            _ = try await client.signInWithBrowser(redirectUri: "io.logto.dev://callback")
        } catch let error as LogtoClientErrors.OidcConfig {
            XCTAssertEqual(error.type, .unableToFetchOidcConfig)
            return
        }

        XCTFail()
    }

    func testSignInUnknownError() async throws {
        let client = buildClient()

        do {
            try await client.signInWithBrowser(
                authSessionType: LogtoAuthSessionFailureMock.self,
                redirectUri: "io.logto.dev://callback"
            )
        } catch let error as LogtoClientErrors.SignIn {
            XCTAssertEqual(error.type, .unknownError)
            return
        }

        XCTFail()
    }
}
