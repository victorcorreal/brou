import SwiftUI

/// The accounts kept for a site, hanging from the sign-in box the caret is
/// in. The same white and hairline as everything else that floats over a
/// page; one line per account, the name in ink and the site under it in
/// grey; a click puts both into the form. The Mac's passkeys for a page
/// waiting for one come first, as in Safari; a click on one brings up the
/// Mac's sheet for it. Its foot opens the passwords panel with this site
/// alone in it. It follows the box when the page scrolls, and goes when the
/// caret does.
struct AccountList: View {
    @ObservedObject var browser: Browser
    let asked: Browser.Suggesting

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(asked.passkeys) { passkey in
                Row(mark: .symbol("person.badge.key"), name: passkey.name,
                    detail: "Passkey" + (passkey.provider.map { " · \($0)" } ?? "")) { browser.choose(passkey) }
            }
            ForEach(asked.logins) { login in
                Row(mark: .letter(login.user.first.map { String($0).uppercased() } ?? "•"),
                    name: login.user.isEmpty ? "No name" : login.user, detail: login.host) { browser.choose(login) }
            }
            if asked.logins.isEmpty {
                Foot(text: "Passkeys on this Mac")
            } else {
                // Where this site's passwords are seen and removed: the
                // panel, with this site alone in it.
                Foot(text: "Manage passwords for this site", act: browser.manageChoice)
            }
        }
        .frame(width: max(240, min(360, asked.spot.width)), alignment: .leading)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 22, y: 8)
        // Just under the box, left edges lined up. The offset is from the
        // stage's top-left, which is also the web view's.
        .offset(x: asked.spot.minX, y: asked.spot.maxY + 6)
    }

    private enum Mark { case letter(String), symbol(String) }

    /// The grey line under the accounts. When it leads somewhere it lights
    /// up under the pointer, as the rows above it do.
    private struct Foot: View {
        let text: String
        var act: (() -> Void)?
        @State private var hovering = false

        var body: some View {
            if let act {
                Button(action: act) { line }
                    .buttonStyle(.plain)
                    .onHover { hovering = $0 }
                    .animation(Motion.quick, value: hovering)
            } else {
                line
            }
        }

        private var line: some View {
            HStack(spacing: 6) {
                Image(systemName: "key")
                    .font(.system(size: 9, weight: .medium))
                Text(text)
                    .font(.system(size: 10.5))
                Spacer(minLength: 0)
                if act != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                }
            }
            // A line that leads somewhere is grey enough to read; one that
            // only says where the accounts come from stays faint.
            .foregroundStyle(hovering ? Palette.ink : (act == nil ? Palette.faint : Palette.muted))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            // The full wash, not the rows' hover: on this grey half-wash
            // the hover grey would not show.
            .background(hovering ? Palette.wash : Palette.wash.opacity(0.5))
            .contentShape(Rectangle())
        }
    }

    private struct Row: View {
        let mark: Mark
        let name: String
        let detail: String
        let pick: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: pick) {
                HStack(spacing: 10) {
                    Group {
                        switch mark {
                        case .letter(let letter): Text(letter).font(.system(size: 11, weight: .medium))
                        case .symbol(let name): Image(systemName: name).font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 22)
                    .background(Palette.wash, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(hovering ? Palette.hover : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }
}
