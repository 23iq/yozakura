import QtQuick
import qs.modules.theme
import qs.modules.services

// "Preview on desktop": collapses the wizard to the peek pill so the user
// can see the real desktop. Put it in a step that changes something visible.
FocusChip {
    icon: Icons.eye
    text: I18n.t("onboarding.peek.preview")
    onClicked: OnboardingService.peek = true
}
