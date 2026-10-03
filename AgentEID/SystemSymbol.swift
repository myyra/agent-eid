import SwiftUI

enum SystemSymbol: String {
    case identityCard = "person.text.rectangle"
    case identityCardFilled = "person.text.rectangle.fill"
    case identityCardError = "person.text.rectangle.trianglebadge.exclamationmark"
    case reader = "externaldrive"
    case settings = "gearshape"
    case statusDot = "circle.fill"
}

extension Image {
    init(systemSymbol: SystemSymbol) {
        self.init(systemName: systemSymbol.rawValue)
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringResource, systemSymbol: SystemSymbol) {
        self.init {
            Text(title)
        } icon: {
            Image(systemSymbol: systemSymbol)
        }
    }
}
