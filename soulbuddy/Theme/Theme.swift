import SwiftUI

// MARK: - Theme
struct Theme {
    // MARK: - Colors
    struct Colors {
        // Primary Colors
        static let primary = Color("Primary")
        static let primaryVariant = Color("PrimaryVariant")
        static let secondary = Color("Secondary")
        static let secondaryVariant = Color("SecondaryVariant")
        
        // Background Colors
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let surfaceVariant = Color("SurfaceVariant")
        
        // Content Colors
        static let onPrimary = Color("OnPrimary")
        static let onSecondary = Color("OnSecondary")
        static let onBackground = Color("OnBackground")
        static let onSurface = Color("OnSurface")
        
        // Status Colors
        static let success = Color("Success")
        static let warning = Color("Warning")
        static let error = Color("Error")
        static let info = Color("Info")
        
        // Text Colors
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")
        static let textDisabled = Color("TextDisabled")
        
        // Interactive Colors
        static let buttonPrimary = Color("ButtonPrimary")
        static let buttonSecondary = Color("ButtonSecondary")
        static let buttonDisabled = Color("ButtonDisabled")
        
        // Border & Divider
        static let border = Color("Border")
        static let divider = Color("Divider")
        
        // Overlay
        static let overlay = Color("Overlay")
        static let modalBackground = Color("ModalBackground")
        
        // Fallback System Colors (when custom colors aren't available)
        struct Fallback {
            static let primary = Color.blue
            static let secondary = Color.purple
            static let background = Color(.systemBackground)
            static let surface = Color(.secondarySystemBackground)
            static let textPrimary = Color(.label)
            static let textSecondary = Color(.secondaryLabel)
            static let success = Color.green
            static let warning = Color.orange
            static let error = Color.red
            static let info = Color.blue
        }
    }
    
    // MARK: - Typography
    struct Typography {
        // Headers
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        
        // Headlines
        static let headline = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        
        // Body Text
        static let bodyLarge = Font.body.weight(.regular)
        static let body = Font.body.weight(.regular)
        static let bodySmall = Font.callout.weight(.regular)
        
        // Labels
        static let labelLarge = Font.callout.weight(.semibold)
        static let label = Font.footnote.weight(.medium)
        static let labelSmall = Font.caption.weight(.medium)
        
        // Caption
        static let caption = Font.caption.weight(.regular)
        static let captionSmall = Font.caption2.weight(.regular)
        
        // Custom Font Modifiers
        static func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
        
        static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .rounded)
        }
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        
        // Semantic Spacing
        static let elementSpacing = md
        static let sectionSpacing = lg
        static let screenPadding = md
        static let cardPadding = md
        static let buttonPadding = sm
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 1000 // For fully rounded corners
        
        // Semantic Corner Radius
        static let button = md
        static let card = lg
        static let modal = xl
        static let textField = sm
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = (
            color: Color.black.opacity(0.1),
            radius: CGFloat(2),
            x: CGFloat(0),
            y: CGFloat(1)
        )
        
        static let medium = (
            color: Color.black.opacity(0.15),
            radius: CGFloat(4),
            x: CGFloat(0),
            y: CGFloat(2)
        )
        
        static let large = (
            color: Color.black.opacity(0.2),
            radius: CGFloat(8),
            x: CGFloat(0),
            y: CGFloat(4)
        )
        
        static let card = medium
        static let button = small
        static let modal = large
    }
    
    // MARK: - Opacity
    struct Opacity {
        static let disabled: Double = 0.6
        static let overlay: Double = 0.8
        static let pressed: Double = 0.8
        static let loading: Double = 0.5
    }
    
    // MARK: - Animation
    struct Animation {
        static let short = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let long = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
        
        // Semantic Animations
        static let buttonPress = short
        static let pageTransition = medium
        static let modalPresentation = medium
    }
    
    // MARK: - Icon Sizes
    struct IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // Semantic Icon Sizes
        static let button = md
        static let tabBar = lg
        static let navigation = md
        static let avatar = xl
    }
}

// MARK: - Color Extensions
extension Color {
    init(_ name: String) {
        self.init(name, bundle: .main)
    }
    
    // Convenience method to create colors that adapt to color scheme
    static func adaptive(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - View Extensions for Theme
extension View {
    // Apply card style
    func cardStyle() -> some View {
        self
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.CornerRadius.card)
            .shadow(
                color: Theme.Shadow.card.color,
                radius: Theme.Shadow.card.radius,
                x: Theme.Shadow.card.x,
                y: Theme.Shadow.card.y
            )
    }
    
    // Apply button style
    func primaryButtonStyle() -> some View {
        self
            .background(Theme.Colors.buttonPrimary)
            .foregroundColor(Theme.Colors.onPrimary)
            .cornerRadius(Theme.CornerRadius.button)
            .shadow(
                color: Theme.Shadow.button.color,
                radius: Theme.Shadow.button.radius,
                x: Theme.Shadow.button.x,
                y: Theme.Shadow.button.y
            )
    }
    
    // Apply screen padding
    func screenPadding() -> some View {
        self.padding(Theme.Spacing.screenPadding)
    }
    
    // Apply section spacing
    func sectionSpacing() -> some View {
        self.padding(.vertical, Theme.Spacing.sectionSpacing)
    }
}

// MARK: - Environment Key for Theme
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
} 