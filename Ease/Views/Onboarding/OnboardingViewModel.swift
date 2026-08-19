import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int {
        case philosophy = 1
        case measurements = 2
        case permissions = 3
    }

    var step: Step = .philosophy
    var heightText = ""
    var currentWeightText = ""
    var targetWeightText = ""
    var errorKey: String?
    var isBusy = false

    var canContinueMeasurements: Bool {
        parsedHeight != nil && parsedCurrentWeight != nil && parsedTargetWeight != nil
    }

    var parsedHeight: Double? {
        guard let value = EaseFormatters.parseDecimal(heightText) else { return nil }
        return (try? MeasurementBounds.validatedHeight(value))
    }

    var parsedCurrentWeight: Double? {
        guard let value = EaseFormatters.parseDecimal(currentWeightText) else { return nil }
        return (try? MeasurementBounds.validatedWeight(value))
    }

    var parsedTargetWeight: Double? {
        guard let value = EaseFormatters.parseDecimal(targetWeightText) else { return nil }
        return (try? MeasurementBounds.validatedWeight(value))
    }

    func goNextFromPhilosophy() {
        errorKey = nil
        step = .measurements
    }

    func goBack() {
        errorKey = nil
        switch step {
        case .philosophy:
            break
        case .measurements:
            step = .philosophy
        case .permissions:
            step = .measurements
        }
    }

    func goNextFromMeasurements() {
        guard canContinueMeasurements else {
            errorKey = "onboarding.error.invalid"
            return
        }
        errorKey = nil
        step = .permissions
    }

    func finish(context: ModelContext, notificationsEnabled: Bool) {
        guard let height = parsedHeight,
              let weight = parsedCurrentWeight,
              let target = parsedTargetWeight else {
            errorKey = "onboarding.error.invalid"
            step = .measurements
            return
        }
        do {
            try UserProfileRepository(context: context).completeOnboarding(
                heightCm: height,
                currentWeight: weight,
                targetWeight: target,
                notificationsEnabled: notificationsEnabled
            )
            Task {
                await NotificationScheduler.refresh(enabled: notificationsEnabled, context: context)
            }
        } catch {
            errorKey = "onboarding.error.invalid"
            step = .measurements
        }
    }

    func continueWithPermissions(context: ModelContext) async {
        isBusy = true
        defer { isBusy = false }
        await PermissionsService.requestHealthKitRead()
        let granted = await PermissionsService.requestNotifications()
        finish(context: context, notificationsEnabled: granted)
    }
}
