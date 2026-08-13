//
//  APIError.swift
//  RoutinityApp
//

import Foundation
import Supabase

/// The backend's edge functions always error with `{ "error": "..." }` (see docs/api-contract.md).
/// `FunctionsError.httpError` only exposes the raw body, so pull that message out for display.
private struct APIErrorBody: Decodable {
    let error: String
}

func friendlyErrorMessage(_ error: Error) -> String {
    guard case let .httpError(code, data) = error as? FunctionsError else {
        return error.localizedDescription
    }
    guard let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) else {
        return "요청 실패 (\(code))"
    }
    return body.error
}
