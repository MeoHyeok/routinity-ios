//
//  AuthView.swift
//  RoutinityApp
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)
                        .frame(width: 76, height: 76)
                        .background(Color.routinityCard, in: Circle())

                    Text("루티니티")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
                .padding(.top, 48)

                Picker("모드", selection: $viewModel.mode) {
                    Text("로그인").tag(AuthViewModel.Mode.signIn)
                    Text("회원가입").tag(AuthViewModel.Mode.signUp)
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    TextField("이메일", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .routinityFieldStyle()

                    SecureField("비밀번호", text: $viewModel.password)
                        .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                        .routinityFieldStyle()
                }

                VStack(spacing: 8) {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let infoMessage = viewModel.infoMessage {
                        Text(infoMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.mode == .signIn ? "로그인" : "가입하기")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
            }
            .padding(24)
        }
        .background(Color.routinityBackground)
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
