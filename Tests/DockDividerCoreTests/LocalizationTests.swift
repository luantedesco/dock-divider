import Foundation
import Testing

private let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
private let resources = projectRoot.appendingPathComponent("Resources")

// The keys of Resources/<language>.lproj/Localizable.strings, by language code.
private func allKeys() throws -> [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for folder in try FileManager.default.contentsOfDirectory(atPath: resources.path) where folder.hasSuffix(".lproj") {
        let url = resources.appendingPathComponent("\(folder)/Localizable.strings")
        let strings = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(folder)")
        result[String(folder.dropLast(".lproj".count))] = Set(strings.keys)
    }
    return result
}

@Test func everyLanguageHasExactlyTheEnglishKeys() throws {
    let languages = try allKeys()
    let english = try #require(languages["en"])

    for (language, keys) in languages where language != "en" {
        #expect(english.subtracting(keys).isEmpty, "\(language) is missing \(english.subtracting(keys).sorted())")
        #expect(keys.subtracting(english).isEmpty, "\(language) has keys not in English: \(keys.subtracting(english).sorted())")
    }
}

// The English text is the key, so every String(localized:) in the code must be in en.lproj.
@Test func everyTextInTheCodeHasAnEnglishKey() throws {
    let english = try #require(try allKeys()["en"])
    let pattern = try Regex(#"String\(localized: "((?:[^"\\]|\\.)*)""#)
    let sources = projectRoot.appendingPathComponent("Sources")
    var missing: [String] = []
    for file in try FileManager.default.subpathsOfDirectory(atPath: sources.path) where file.hasSuffix(".swift") {
        let code = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
        for match in code.matches(of: pattern) {
            let key = String(match.output[1].substring ?? "")
            if !english.contains(key) { missing.append("\(file): \(key)") }
        }
    }

    #expect(missing.isEmpty, "\(missing)")
}
