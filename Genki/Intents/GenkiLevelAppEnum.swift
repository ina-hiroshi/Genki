import AppIntents

/// App Intent / Shortcuts 用の元気度。
enum GenkiLevelAppEnum: String, AppEnum {
    case great
    case okay
    case rough

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("genki_level_picker_title"))
    }

    static var caseDisplayRepresentations: [GenkiLevelAppEnum: DisplayRepresentation] {
        [
            .great: DisplayRepresentation(title: LocalizedStringResource("genki_level_great")),
            .okay: DisplayRepresentation(title: LocalizedStringResource("genki_level_okay")),
            .rough: DisplayRepresentation(title: LocalizedStringResource("genki_level_rough"))
        ]
    }

    var genkiLevel: GenkiLevel {
        switch self {
        case .great: .great
        case .okay: .okay
        case .rough: .rough
        }
    }
}
