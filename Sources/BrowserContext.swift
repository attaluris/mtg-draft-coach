import Cocoa

struct DraftLocation: Equatable {
    let draftID: String
    let pack: Int
    let pick: Int
    /// Live drafts (`/site_draft/<id>`) have no pack/pick in the URL; the current
    /// position is the first pick in the data that has not been made yet.
    var live = false
}

func parseDraftLocation(_ value: String) -> DraftLocation? {
    guard let url = URL(string: value),
          url.host?.hasSuffix("17lands.com") == true else { return nil }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard parts.count >= 2,
          ["site_draft_replay", "submitted_draft", "site_draft"].contains(parts[0]),
          parts[1].range(of: "^[a-fA-F0-9]{32}$", options: .regularExpression) != nil else { return nil }
    if parts[0] == "site_draft" { return DraftLocation(draftID: parts[1], pack: 1, pick: 1, live: true) }
    let pack = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
    let pick = parts.count > 3 ? (Int(parts[3]) ?? 1) : 1
    return DraftLocation(draftID: parts[1], pack: min(max(pack, 1), 3), pick: min(max(pick, 1), 15))
}

func activeChromeURL() -> String? {
    // Never let the AppleScript launch Chrome when it isn't already running.
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty else { return nil }
    let source = "tell application \"Google Chrome\" to get URL of active tab of front window"
    var error: NSDictionary?
    return NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
}

enum PageHeading { case found(pack: Int, pick: Int), none, scriptingOff }

/// Reads "Pack N Pick M" from the active Chrome tab's own text. Purely local: no
/// network. Needs Chrome › View › Developer › Allow JavaScript from Apple Events.
func activeChromePickHeading() -> PageHeading {
    let js = "(document.body.innerText.match(/Pack\\s+(\\d+)\\s+Pick\\s+(\\d+)/i)||[''])[0]"
    let result = runChromeJavaScript(js)
    return result.scriptingOff ? .scriptingOff : parsePickHeading(result.text ?? "")
}

/// Runs JavaScript in Chrome's active tab via Apple Events. Returns nil text with
/// scriptingOff = true when Chrome's "Allow JavaScript from Apple Events" is off.
/// With `inDraftTab`, runs in the first tab showing a 17Lands draft (the active tab
/// if it is one, else any tab in any window) without switching tabs.
func runChromeJavaScript(_ js: String, inDraftTab: Bool = false) -> (text: String?, scriptingOff: Bool) {
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty else { return (nil, false) }
    let escaped = js.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let source = inDraftTab ? """
        tell application "Google Chrome"
            set target to missing value
            if (count of windows) > 0 then
                if URL of active tab of front window contains "17lands.com/site_draft/" then set target to active tab of front window
            end if
            if target is missing value then
                repeat with w in windows
                    repeat with t in tabs of w
                        if target is missing value and URL of t contains "17lands.com/site_draft/" then set target to t
                    end repeat
                end repeat
            end if
            if target is missing value then return ""
            return execute target javascript "\(escaped)"
        end tell
        """ : "tell application \"Google Chrome\" to execute active tab of front window javascript \"\(escaped)\""
    var error: NSDictionary?
    let text = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
    let off = (error?[NSAppleScript.errorMessage] as? String)?.localizedCaseInsensitiveContains("JavaScript") ?? false
    return (text, off)
}

struct DeckSplit: Equatable {
    let maindeck: [String]
    let sideboard: [String]
}

enum DeckRead { case found(DeckSplit), notFound, scriptingOff }

/// Reads your Maindeck and Sideboard from the 17Lands deck builder in the active
/// Chrome tab: card images carry the card name as alt text, and everything between
/// the "Maindeck" and "Sideboard" headings is in the maindeck. Local only.
func activeChromeDeckSplit() -> DeckRead {
    let js = """
    (function(){var hs=[].slice.call(document.querySelectorAll('h1,h2,h3'));    var md=hs.find(function(h){return /^Maindeck/i.test(h.textContent.trim())});    var sb=hs.find(function(h){return /^Sideboard/i.test(h.textContent.trim())});    if(!md)return '';var F=Node.DOCUMENT_POSITION_FOLLOWING;    var after=function(a,b){return !!(a&&b&&(a.compareDocumentPosition(b)&F))};    var imgs=[].slice.call(document.querySelectorAll('img[alt]'));    return JSON.stringify({main:imgs.filter(function(i){return after(md,i)&&(!sb||after(i,sb))}).map(function(i){return i.alt}),    side:imgs.filter(function(i){return after(sb,i)}).map(function(i){return i.alt})})})()
    """
    let result = runChromeJavaScript(js, inDraftTab: true)
    if result.scriptingOff { return .scriptingOff }
    return parseDeckSplit(result.text ?? "").map(DeckRead.found) ?? .notFound
}

func parseDeckSplit(_ json: String) -> DeckSplit? {
    guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
          let main = object["main"] as? [String], !main.isEmpty else { return nil }
    return DeckSplit(maindeck: main, sideboard: object["side"] as? [String] ?? [])
}

/// "3× Fatehold Chronologist" lines, in first-seen order.
func countedList(_ names: [String]) -> String {
    var order: [String] = [], counts: [String: Int] = [:]
    for name in names where !name.isEmpty {
        if counts[name] == nil { order.append(name) }
        counts[name, default: 0] += 1
    }
    return order.map { "- \(counts[$0]!)× \($0)" }.joined(separator: "\n")
}

func parsePickHeading(_ text: String) -> PageHeading {
    let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    guard numbers.count >= 2 else { return .none }
    return .found(pack: numbers[0], pick: numbers[1])
}

private func safeCard(_ card: [String: Any], stats: [String: Any] = [:]) -> [String: Any] {
    var output: [String: Any] = [:]
    for key in ["name", "mana_cost", "layout"] {
        if let value = card[key] as? String { output[key] = value }
    }
    if let types = card["types"] as? [String] { output["types"] = types }
    if let cost = card["mana_cost"] as? String { output["colors"] = colors(in: cost) }
    // Aggregate 17Lands numbers, not anything about this specific draft's future.
    if let name = card["name"] as? String, let row = stats[name] as? [String: Any] {
        if let rate = row["game_in_hand_win_rate"] as? Double { output["gih_win_rate"] = NSDecimalNumber(string: String(format: "%.1f", rate * 100)) }
        if let seen = row["avg_seen_position"] as? Double { output["avg_seen_position"] = NSDecimalNumber(string: String(format: "%.1f", seen)) }
    }
    return output
}

/// Color identity from a mana cost like "{2}{G}" or "{1}{G/U}". Empty means colorless.
func colors(in manaCost: String) -> String {
    let symbols = Set(manaCost.uppercased().filter { "WUBRG".contains($0) })
    return "WUBRG".filter { symbols.contains($0) }.map(String.init).joined()
}

@MainActor
func writeDraftContext(pageURL: String, to destination: URL) async throws -> DraftLocation? {
    guard let location = parseDraftLocation(pageURL) else { return nil }
    let (root, picks) = try await fetchDraftData(location.draftID)
    let resolved = resolveLocation(location, picks: picks)
    let sanitized = try sanitizeDraftContext(root: root, pageURL: pageURL, location: resolved, picks: picks)
    let output = try JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted, .sortedKeys])
    try output.write(to: destination, options: .atomic)
    return resolved
}

// 17Lands blocks clients that request too often (it 403'd this Mac when Auto-coach
// polled every 3 s). All requests go through this guard: a short cache, a minimum
// gap between requests, and a long pause after a 403/429.
@MainActor private var draftCache: (id: String, at: Date, root: [String: Any], picks: [[String: Any]])?
@MainActor private var lastRequest = Date.distantPast
@MainActor private(set) var seventeenLandsPausedUntil = Date.distantPast
let seventeenLandsMinimumGap: TimeInterval = 15

@MainActor
func canQuery17Lands() -> Bool {
    Date() >= seventeenLandsPausedUntil && Date().timeIntervalSince(lastRequest) >= seventeenLandsMinimumGap
}

@MainActor
func fetchDraftData(_ draftID: String) async throws -> (root: [String: Any], picks: [[String: Any]]) {
    if let cached = draftCache, cached.id == draftID, Date().timeIntervalSince(cached.at) < 10 {
        return (cached.root, cached.picks)
    }
    guard Date() >= seventeenLandsPausedUntil else {
        throw NSError(domain: "DraftCoach", code: 5, userInfo: [NSLocalizedDescriptionKey:
            "17Lands asked us to slow down; paused until \(seventeenLandsPausedUntil.formatted(date: .omitted, time: .shortened))."])
    }
    lastRequest = Date()
    let (root, picks) = try await requestDraftData(draftID)
    draftCache = (draftID, Date(), root, picks)
    return (root, picks)
}

private func requestDraftData(_ draftID: String) async throws -> (root: [String: Any], picks: [[String: Any]]) {
    var components = URLComponents(string: "https://www.17lands.com/data/site_draft_replay")!
    components.queryItems = [URLQueryItem(name: "draft_id", value: draftID)]
    var request = URLRequest(url: components.url!)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 15
    let (data, response) = try await URLSession.shared.data(for: request)
    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
    if code == 403 || code == 429 {
        await MainActor.run { seventeenLandsPausedUntil = Date().addingTimeInterval(15 * 60) }
        throw NSError(domain: "DraftCoach", code: 6, userInfo: [NSLocalizedDescriptionKey:
            "17Lands is refusing requests (\(code)); Draft Coach paused 17Lands for 15 minutes."])
    }
    guard code == 200,
          let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let picks = root["picks"] as? [[String: Any]] else {
        throw NSError(domain: "DraftCoach", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "17Lands did not return replay data."])
    }
    return (root, picks)
}

/// Every card drafted so far, with mana cost, colors, types and 17Lands win rates,
/// for deck building. Returns the number of cards written.
@MainActor
func writePoolContext(draftID: String, to destination: URL) async throws -> Int {
    let (root, picks) = try await fetchDraftData(draftID)
    let stats = root["card_performance_data"] as? [String: Any] ?? [:]
    let pool: [[String: Any]] = picks.flatMap { entry -> [[String: Any]] in
        if let multiple = entry["picks"] as? [[String: Any]], !multiple.isEmpty { return multiple.map { safeCard($0, stats: stats) } }
        if let one = entry["pick"] as? [String: Any] { return [safeCard(one, stats: stats)] }
        return []
    }
    guard !pool.isEmpty else {
        throw NSError(domain: "DraftCoach", code: 7, userInfo: [NSLocalizedDescriptionKey: "17Lands has no picks for this draft yet."])
    }
    let output: [String: Any] = [
        "source": "17Lands draft data (Draft Coach)",
        "expansion": root["expansion"] as? String ?? "",
        "pool_size": pool.count,
        "pool": pool,
        "notes": "colors come from mana_cost (W white, U blue, B black, R red, G green; empty = colorless). gih_win_rate is the 17Lands games-in-hand win rate in percent."
    ]
    try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: destination, options: .atomic)
    return pool.count
}

/// The pick waiting for you in a live draft: the first entry with cards to choose
/// from and no recorded choice. Nil once the draft is finished.
func pendingLocation(_ location: DraftLocation, picks: [[String: Any]]) -> DraftLocation? {
    let waiting = picks.filter { !($0["pick"] is [String: Any]) && !(($0["available"] as? [Any]) ?? []).isEmpty }
    guard let current = waiting.min(by: {
        ($0["pack_number"] as? Int ?? 0, $0["pick_number"] as? Int ?? 0) < ($1["pack_number"] as? Int ?? 0, $1["pick_number"] as? Int ?? 0)
    }) else { return nil }
    return DraftLocation(draftID: location.draftID, pack: (current["pack_number"] as? Int ?? 0) + 1,
                         pick: (current["pick_number"] as? Int ?? 0) + 1, live: true)
}

/// For a live draft, the current pick is the first entry without a recorded choice
/// (or the last entry if every pick has been made).
func resolveLocation(_ location: DraftLocation, picks: [[String: Any]]) -> DraftLocation {
    guard location.live else { return location }
    let ordered = picks.sorted {
        let a = ($0["pack_number"] as? Int ?? 0, $0["pick_number"] as? Int ?? 0)
        let b = ($1["pack_number"] as? Int ?? 0, $1["pick_number"] as? Int ?? 0)
        return a < b
    }
    guard let current = ordered.first(where: { !($0["pick"] is [String: Any]) }) ?? ordered.last else { return location }
    return DraftLocation(draftID: location.draftID, pack: (current["pack_number"] as? Int ?? 0) + 1,
                         pick: (current["pick_number"] as? Int ?? 0) + 1, live: true)
}

func sanitizeDraftContext(root: [String: Any], pageURL: String, location: DraftLocation,
                          picks: [[String: Any]]? = nil) throws -> [String: Any] {
    let allPicks = picks ?? (root["picks"] as? [[String: Any]] ?? [])
    let targetPack = location.pack - 1
    let targetPick = location.pick - 1
    guard let current = allPicks.first(where: {
        ($0["pack_number"] as? Int) == targetPack && ($0["pick_number"] as? Int) == targetPick
    }) else {
        throw NSError(domain: "DraftCoach", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "This pack and pick were not found in the replay."])
    }

    let earlier = allPicks.filter {
        let pack = $0["pack_number"] as? Int ?? 99
        let pick = $0["pick_number"] as? Int ?? 99
        return pack < targetPack || (pack == targetPack && pick < targetPick)
    }
    let stats = root["card_performance_data"] as? [String: Any] ?? [:]
    let priorCards: [[String: Any]] = earlier.flatMap { entry in
        if let multiple = entry["picks"] as? [[String: Any]] { return multiple.map { safeCard($0) } }
        if let one = entry["pick"] as? [String: Any] { return [safeCard(one)] }
        return []
    }
    let available = (current["available"] as? [[String: Any]] ?? []).map { safeCard($0, stats: stats) }

    // Intentionally omit the current recorded pick and every later pick. This keeps
    // replay coaching limited to information that was available at the decision.
    return [
        "source": "17Lands replay data (sanitized by Draft Coach)",
        "source_url": pageURL,
        "expansion": root["expansion"] as? String ?? "",
        "position": ["pack": location.pack, "pick": location.pick],
        "notes": "colors come from mana_cost (W white, U blue, B black, R red, G green; empty = colorless). gih_win_rate is the 17Lands games-in-hand win rate in percent; avg_seen_position is how late the card is usually still available.",
        "available_cards": available,
        "previous_picks": priorCards
    ]
}
