//
//  AuthView.swift
//  RoutinityApp
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("루티니티")
                .font(.largeTitle.bold())

            Picker("모드", selection: $viewModel.mode) {
                Text("로그인").tag(AuthViewModel.Mode.signIn)
                Text("회원가입").tag(AuthViewModel.Mode.signUp)
            }
            .pickerStyle(.segmented)

            TextField("이메일", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)

            SecureField("비밀번호", text: $viewModel.password)
                .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                .textFieldStyle(.roundedBorder)

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

            Button {
                Task { await viewModel.submit() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.mode == .signIn ? "로그인" : "가입하기")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
        }
        .padding()
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
