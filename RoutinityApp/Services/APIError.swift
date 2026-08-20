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
    // `URLError.localizedDescription` is raw, untranslated OS text (e.g. "The Internet connection
    // appears to be offline.") — this is the single most common real-world failure (wifi/cellular
    // drops mid-request), so it's worth translating explicitly rather than falling through to the
    // generic `error.localizedDescription` below, which would otherwise leak English into an
    // all-Korean UI on every dropped connection.
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .timedOut:
            return "네트워크 연결을 확인해주세요."
        default:
            break
        }
    }
    guard case let .httpError(code, data) = error as? FunctionsError else {
        return error.localizedDescription
    }
    // The backend's rate-limit body is a fixed, untranslated English string (see
    // docs/api-contract.md) — every other error body is our own Korean text, but this one would
    // otherwise leak raw English into an all-Korean UI, and the doc's own guidance for 429 is to
    // show a "잠시 후 다시 시도" prompt rather than surfacing the body at all.
    guard code != 429 else {
        return "요청이 너무 많아요. 잠시 후 다시 시도해주세요."
    }
    guard let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) else {
        return "요청 실패 (\(code))"
    }
    return body.error
}

/// `AuthError.message`/`localizedDescription` are the raw strings Supabase Auth's server
/// returns — untranslated English like "Email rate limit exceeded" — so unlike
/// `friendlyErrorMessage` above (which decodes our own edge functions' Korean error bodies),
/// this maps by `errorCode` instead of surfacing the message text directly.
func friendlyAuthErrorMessage(_ error: Error) -> String {
    guard let authError = error as? AuthError else {
        return "로그인 처리 중 문제가 발생했어요. 잠시 후 다시 시도해주세요."
    }
    switch authError.errorCode {
    case .invalidCredentials:
        return "이메일 또는 비밀번호가 올바르지 않아요."
    case .emailExists, .userAlreadyExists:
        return "이미 가입된 이메일이에요. 로그인을 시도해주세요."
    case .weakPassword:
        return "비밀번호가 너무 짧아요. 6자 이상으로 입력해주세요."
    case .overEmailSendRateLimit, .overRequestRateLimit, .overSMSSendRateLimit:
        return "요청이 너무 많아요. 잠시 후 다시 시도해주세요."
    case .emailNotConfirmed:
        return "이메일 인증이 필요해요. 받은 메일함을 확인해주세요."
    default:
        return "로그인 처리 중 문제가 발생했어요 (\(authError.errorCode.rawValue))."
    }
}
