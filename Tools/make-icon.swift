// Gera o AppIcon.icns a partir de Resources/icon.svg. O build.sh chama a cada build.
// Uso: swift Tools/make-icon.swift <saída.icns>
import AppKit

// O .icns é montado à mão, com os tipos explícitos de cada tamanho: o macOS atual lê errado
// os PNGs nos tipos legados pequenos (16 e 32 em 1x) e reduz o ic07 para eles.
let sizes: [(type: String, pixels: Int)] = [
    ("ic11", 32), ("ic12", 64), ("ic07", 128), ("ic13", 256),
    ("ic08", 256), ("ic14", 512), ("ic09", 512), ("ic10", 1024),
]

let projectDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let svg = NSImage(contentsOf: projectDir.appendingPathComponent("Resources/icon.svg"))!
let output = URL(fileURLWithPath: CommandLine.arguments[1])

func png(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    svg.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Formato: "icns" + tamanho total; depois, por entrada, tipo + tamanho (cabeçalho incluso) + PNG.
func header(_ type: String, _ length: Int) -> Data {
    Data(type.utf8) + withUnsafeBytes(of: UInt32(length).bigEndian) { Data($0) }
}

let body = sizes.reduce(Data()) { data, size in
    let image = png(size.pixels)
    return data + header(size.type, 8 + image.count) + image
}
try! (header("icns", 8 + body.count) + body).write(to: output)
print("OK: \(output.path)")
