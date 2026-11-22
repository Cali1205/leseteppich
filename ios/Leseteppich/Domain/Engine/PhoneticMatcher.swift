import Foundation

/// Platform-independent German phonetic matcher optimized for 1st-grade readers
/// (isolated sounds, syllables, pseudo-words, and short rebus sentences).
/// Designed to port 1:1 to Kotlin (`PhoneticMatcher.kt`) using the shared test vectors.
public struct PhoneticMatcher: Sendable {
    public init() {}

    /// Built-in German ASR transcription equivalents for isolated single phonemes
    /// (so both built-in and parent-created custom carpets recognize single sounds like "a", "i", "n", "o").
    private static let singlePhonemeNormalVariants: [String: [String]] = [
        "a": ["a", "ah", "aa", "aaa", "aah", "ha"],
        "e": ["e", "eh", "ee", "eee", "eeh"],
        "i": ["i", "ih", "ie", "ii", "iii", "ieh", "hi"],
        "o": ["o", "oh", "oo", "ooo", "ooh", "ho"],
        "u": ["u", "uh", "uu", "uuu", "uuh", "hu"],
        "n": ["n", "en", "enn", "nn", "nnn", "in"],
        "m": ["m", "em", "emm", "mm", "mmm", "im"],
        "l": ["l", "el", "ell", "ll", "lll"],
        "s": ["s", "es", "ess", "ss", "sss"],
        "t": ["t", "te", "tee", "tt"],
        "p": ["p", "pe", "pee", "pp"]
    ]

    /// Additional breathy/hesitation ASR artifacts allowed in `.gentle` (beginner) mode.
    private static let singlePhonemeGentleExtras: [String: [String]] = [
        "a": ["äh", "aeh", "ar", "ab"],
        "i": ["ich", "di", "die"],
        "n": ["hm", "hmm", "ähm", "ne"],
        "m": ["hm", "hmm", "ähm", "ma"],
        "s": ["ist", "se", "ze"],
        "l": ["la", "le"],
        "t": ["de", "ti", "ta"],
        "p": ["be", "pa", "pi"]
    ]

    public func match(
        hypotheses: [String],
        tile: ReadingTile,
        strictness: MatchingStrictness = .normal
    ) -> RecognitionMatchResult {
        var targets = [tile.spokenText, tile.display]
        targets.append(contentsOf: tile.acceptedTranscriptions)
        let normalizedDisplay = normalizeBasic(tile.display)
        let expected = normalizedDisplay.count == 1 ? normalizedDisplay : tile.spokenText
        return match(hypotheses: hypotheses, expected: expected, accepted: targets, strictness: strictness)
    }

    public func match(
        hypotheses: [String],
        expected: String,
        accepted: [String] = [],
        strictness: MatchingStrictness = .normal
    ) -> RecognitionMatchResult {
        let cleanedHypotheses = hypotheses
            .map { normalizeBasic($0) }
            .filter { !$0.isEmpty }

        guard !cleanedHypotheses.isEmpty else {
            return RecognitionMatchResult(
                isMatch: false,
                confidence: 0.0,
                matchedHypothesis: nil,
                reason: "empty_input"
            )
        }

        var rawTargets: [String] = [expected] + accepted

        // Automatically enrich 1-letter German phonemes so custom carpets also work reliably.
        let normalizedExpected = normalizeBasic(expected)
        if normalizedExpected.count == 1 {
            if let normalExtras = Self.singlePhonemeNormalVariants[normalizedExpected] {
                rawTargets.append(contentsOf: normalExtras)
            }
            if strictness == .gentle, let gentleExtras = Self.singlePhonemeGentleExtras[normalizedExpected] {
                rawTargets.append(contentsOf: gentleExtras)
            }
        }

        let candidateTargets = Array(Set(rawTargets.map { normalizeBasic($0) }.filter { !$0.isEmpty }))

        // 1. Exact normalized or spaceless match (also checking individual tokens for short filler prefixes)
        for rawHyp in hypotheses {
            let hyp = normalizeBasic(rawHyp)
            let hypParts = candidateSubstrings(from: hyp)
            for target in candidateTargets {
                let targetCompact = target.replacingOccurrences(of: " ", with: "")
                for part in hypParts {
                    let partCompact = part.replacingOccurrences(of: " ", with: "")
                    if part == target || partCompact == targetCompact {
                        return RecognitionMatchResult(
                            isMatch: true,
                            confidence: 1.0,
                            matchedHypothesis: rawHyp,
                            reason: "exact"
                        )
                    }
                }
            }
        }

        // 2. German phonetic key match (with optional child voicing tolerance in gentle mode)
        let allowSoftConsonants = (strictness == .gentle)
        for rawHyp in hypotheses {
            let hyp = normalizeBasic(rawHyp)
            let hypParts = candidateSubstrings(from: hyp)
            for target in candidateTargets {
                let targetKey = phoneticKey(of: target, softConsonants: allowSoftConsonants)
                for part in hypParts {
                    let partKey = phoneticKey(of: part, softConsonants: allowSoftConsonants)
                    if !targetKey.isEmpty && partKey == targetKey {
                        return RecognitionMatchResult(
                            isMatch: true,
                            confidence: allowSoftConsonants ? 0.92 : 0.96,
                            matchedHypothesis: rawHyp,
                            reason: allowSoftConsonants ? "phonetic_gentle" : "phonetic"
                        )
                    }
                }
            }
        }

        // 3. Controlled Levenshtein similarity on phonetic keys (only for multi-character targets, never in strict mode)
        if strictness != .strict {
            let threshold: Double = (strictness == .gentle) ? 0.75 : 0.84
            var bestScore = 0.0
            var bestHyp: String?

            for rawHyp in hypotheses {
                let hyp = normalizeBasic(rawHyp)
                let hypParts = candidateSubstrings(from: hyp)
                for target in candidateTargets {
                    let targetKey = phoneticKey(of: target, softConsonants: allowSoftConsonants)
                    // Avoid false positives on 1-2 letter syllables like "ma" vs "so"
                    guard targetKey.count >= 4 else { continue }
                    for part in hypParts {
                        let partKey = phoneticKey(of: part, softConsonants: allowSoftConsonants)
                        let score = similarity(partKey, targetKey)
                        if score > bestScore {
                            bestScore = score
                            bestHyp = rawHyp
                        }
                    }
                }
            }

            if bestScore >= threshold, let matched = bestHyp {
                return RecognitionMatchResult(
                    isMatch: true,
                    confidence: bestScore,
                    matchedHypothesis: matched,
                    reason: "fuzzy_phonetic"
                )
            }
        }

        return RecognitionMatchResult(
            isMatch: false,
            confidence: 0.0,
            matchedHypothesis: nil,
            reason: "no_match"
        )
    }

    public func normalizeBasic(_ input: String) -> String {
        let lower = input.lowercased(with: Locale(identifier: "de_DE"))
        let allowed = lower.unicodeScalars.map { scalar -> Character in
            if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return String(allowed)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Converts German text into a simplified phonetic key for child ASR comparison.
    public func phoneticKey(of text: String, softConsonants: Bool) -> String {
        var s = collapseRepeats(normalizeBasic(text).replacingOccurrences(of: " ", with: ""))
        guard !s.isEmpty else { return "" }

        let replacements: [(String, String)] = [
            ("ß", "s"),
            ("ä", "e"),
            ("ö", "oe"),
            ("ü", "ue"),
            ("ie", "i"),
            ("ih", "i"),
            ("ah", "a"),
            ("eh", "e"),
            ("oh", "o"),
            ("uh", "u"),
            ("th", "t"),
            ("ph", "f"),
            ("ck", "k"),
            ("tz", "z"),
            ("ei", "ai"),
            ("ey", "ai"),
            ("ay", "ai"),
            ("y", "i")
        ]

        for (from, to) in replacements {
            s = s.replacingOccurrences(of: from, with: to)
        }

        if softConsonants {
            let softMap: [(String, String)] = [
                ("d", "t"),
                ("b", "p"),
                ("g", "k"),
                ("v", "f"),
                ("w", "f"),
                ("z", "s")
            ]
            for (from, to) in softMap {
                s = s.replacingOccurrences(of: from, with: to)
            }
        }

        return collapseRepeats(s)
    }

    private func collapseRepeats(_ input: String) -> String {
        var collapsed = ""
        var previous: Character?
        for ch in input {
            if ch != previous {
                collapsed.append(ch)
                previous = ch
            }
        }
        return collapsed
    }

    private func candidateSubstrings(from normalized: String) -> [String] {
        var result: [String] = [normalized]
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        if compact != normalized {
            result.append(compact)
        }
        let tokens = normalized.split(separator: " ").map(String.init)
        if tokens.count > 1 {
            // Also check individual tokens (handles filler words like "ähm Mama")
            result.append(contentsOf: tokens)
            // And adjacent token pairs (handles split 2-syllable words inside longer speech)
            if tokens.count >= 2 {
                for idx in 0..<(tokens.count - 1) {
                    result.append(tokens[idx] + tokens[idx + 1])
                }
            }
        }
        return result
    }

    public func similarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1.0 }
        let maxLen = max(lhs.count, rhs.count)
        guard maxLen > 0 else { return 1.0 }
        let dist = levenshteinDistance(lhs, rhs)
        return max(0.0, 1.0 - Double(dist) / Double(maxLen))
    }

    public func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previousRow = Array(0...b.count)
        for i in 1...a.count {
            var currentRow = Array(repeating: 0, count: b.count + 1)
            currentRow[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }
            previousRow = currentRow
        }
        return previousRow[b.count]
    }
}
