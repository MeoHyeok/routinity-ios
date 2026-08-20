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

/// Every `{ "error": "..." }` body the backend actually sends is a fixed, hardcoded **English**
/// string (see docs/api-contract.md — none of it is per-request dynamic content), so it's never
/// our own Korean text like `friendlyAuthErrorMessage`'s doc comment used to assume. Translating
/// each known phrase here instead of surfacing the body directly keeps the UI consistently
/// Korean; anything not in this table (a future backend message this list hasn't caught up to
/// yet) falls back to a generic Korean message with the status code rather than leaking English.
private let knownAPIErrorTranslations: [String: String] = [
    "rate limit exceeded, try again later": "요청이 너무 많아요. 잠시 후 다시 시도해주세요.",
    "log not found": "해당 기록을 찾을 수 없어요.",
    "goal not found": "해당 목표를 찾을 수 없어요. 이미 삭제됐을 수 있어요.",
    "target_value must be HH:MM (24h)": "시간 형식이 올바르지 않아요. HH:MM 형식으로 입력해주세요.",
    "target_value must be a positive integer (minutes)": "공부 시간 목표는 1 이상의 숫자(분)로 입력해주세요.",
    "target_value must be at most 1440 (minutes in a day)": "공부 시간 목표는 하루(1440분)를 넘을 수 없어요.",
]

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
    guard let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) else {
        return "요청 실패 (\(code))"
    }
    return knownAPIErrorTranslations[body.error] ?? "요청 처리 중 문제가 발생했어요 (\(code))"
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
