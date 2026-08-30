#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit

enum MacBarcodeWedgeInput {
    private static let minLength = 3

    static func normalizedScan(from raw: String) -> String? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.newlines).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.count >= minLength else { return nil }
        return BarcodeMatching.normalize(trimmed)
    }

    static func normalizedScanFromSearchField(_ text: String) -> String? {
        guard text.contains("\n") || text.contains("\r") else { return nil }
        return normalizedScan(from: text)
    }
}

private struct MacBarcodeCaptureField: UIViewRepresentable {
    @Binding var text: String
    let isEnabled: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        field.delegate = context.coordinator
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.isHidden = true
        field.alpha = 0.01
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = $text
        if isEnabled, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isEnabled, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        let onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text.wrappedValue = textField.text ?? ""
            if text.wrappedValue.contains("\n") || text.wrappedValue.contains("\r") {
                onSubmit()
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return true
        }
    }
}

private struct MacBarcodeWedgeCaptureModifier: ViewModifier {
    let isEnabled: Bool
    let onScan: (String) -> Void

    @State private var buffer = ""

    func body(content: Content) -> some View {
        content
            .background(
                MacBarcodeCaptureField(
                    text: $buffer,
                    isEnabled: isEnabled,
                    onSubmit: submitBuffer
                )
            )
            .onChange(of: isEnabled) { enabled in
                if !enabled {
                    buffer = ""
                }
            }
    }

    private func submitBuffer() {
        guard let code = MacBarcodeWedgeInput.normalizedScan(from: buffer) else {
            buffer = ""
            return
        }
        buffer = ""
        onScan(code)
    }
}

extension View {
    func macBarcodeWedgeCapture(isEnabled: Bool, onScan: @escaping (String) -> Void) -> some View {
        modifier(MacBarcodeWedgeCaptureModifier(isEnabled: isEnabled, onScan: onScan))
    }
}
#endif
