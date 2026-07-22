import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR rendering for challenge links — CoreImage's built-in generator,
/// upscaled without smoothing so the modules stay crisp. Procedural, like
/// everything else.
enum QRCode {
    static func image(for text: String, scale: CGFloat = 10) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return Image(cgImage, scale: 1, label: Text(verbatim: text))
            .interpolation(.none)
    }
}
