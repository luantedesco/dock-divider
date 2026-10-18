// Checks the translations: every language in Resources/*.lproj has exactly the keys of English,
// and every String(localized:) in Sources has a key in English. Exits with 1 on any problem.
// Usage: swift Tools/check-strings.swift
import Foundation

let projectDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let resources = projectDir.appendingPathComponent("Resources")
let files = FileManager.default

func keys(_ language: String) -> Set<String> {
    let url = resources.appendingPathComponent("\(language).lproj/Localizable.strings")
    guard let strings = NSDictionary(contentsOf: url) as? [String: String] else {
        print("\(language): cannot read \(url.path)")
        exit(1)
    }
    return Set(strings.keys)
}

let english = keys("en")
var problems: [String] = []

let languages = try! files.contentsOfDirectory(atPath: resources.path)
    .filter { $0.hasSuffix(".lproj") }
    .map { String($0.dropLast(".lproj".count)) }
    .sorted()
for language in languages where language != "en" {
    let translated = keys(language)
    problems += english.subtracting(translated).sorted().map { "\(language): missing \"\($0)\"" }
    problems += translated.subtracting(english).sorted().map { "\(language): not in English: \"\($0)\"" }
}

let localized = try! NSRegularExpression(pattern: #"String\(localized: "((?:[^"\\]|\\.)*)""#)
let sources = files.enumerator(at: projectDir.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)!
for case let url as URL in sources where url.pathExtension == "swift" {
    let code = try! String(contentsOf: url, encoding: .utf8)
    for match in localized.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
        let key = String(code[Range(match.range(at: 1), in: code)!])
        if !english.contains(key) { problems.append("en: missing \"\(key)\", used in \(url.lastPathComponent)") }
    }
}

if problems.isEmpty {
    print("OK: \(languages.joined(separator: ", "))")
} else {
    problems.forEach { print($0) }
    exit(1)
}
