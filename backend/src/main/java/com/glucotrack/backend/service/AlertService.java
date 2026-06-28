package com.glucotrack.backend.service;

import com.glucotrack.backend.entity.Alert;
import com.glucotrack.backend.entity.FamilyConnection;
import com.glucotrack.backend.entity.GlucoseReading;
import com.glucotrack.backend.entity.Profile;
import com.glucotrack.backend.enums.AlertSeverity;
import com.glucotrack.backend.enums.AlertType;
import com.glucotrack.backend.enums.ConnectionStatus;
import com.glucotrack.backend.repository.AlertRepository;
import com.glucotrack.backend.repository.FamilyConnectionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AlertService {

    private final AlertRepository alertRepository;
    private final FamilyConnectionRepository connectionRepository;

    /**
     * Avalia uma medição recém-registrada e cria alertas se necessário.
     * Chamado automaticamente após salvar qualquer medição de glicemia.
     */
    public void evaluateReading(GlucoseReading reading, Profile user) {
        int value = reading.getValue();
        int targetMin = user.getTargetMin();
        int targetMax = user.getTargetMax();

        AlertType alertType = null;
        AlertSeverity severity = null;
        String message = null;

        if (value < 54) {
            alertType = AlertType.HYPOGLYCEMIA_SEVERE;
            severity = AlertSeverity.EMERGENCY;
            message = String.format(
                "⚠️ EMERGÊNCIA: glicemia de %d mg/dL — hipoglicemia severa! Ação imediata necessária.", value);
        } else if (value < 70) {
            alertType = AlertType.HYPOGLYCEMIA;
            severity = AlertSeverity.CRITICAL;
            message = String.format(
                "🔴 Hipoglicemia: glicemia de %d mg/dL está abaixo de 70 mg/dL. Consumir carboidratos rápidos.", value);
        } else if (value >= 250) {
            alertType = AlertType.HYPERGLYCEMIA_SEVERE;
            severity = AlertSeverity.CRITICAL;
            message = String.format(
                "🔴 Hiperglicemia severa: glicemia de %d mg/dL está acima de 250 mg/dL.", value);
        } else if (value > targetMax) {
            alertType = AlertType.HYPERGLYCEMIA;
            severity = AlertSeverity.WARNING;
            message = String.format(
                "🟡 Glicemia de %d mg/dL acima da meta (> %d mg/dL).", value, targetMax);
        }

        if (alertType != null) {
            createAlert(reading, user, alertType, severity, message, value);
        }
    }

    private void createAlert(GlucoseReading reading, Profile user,
                              AlertType type, AlertSeverity severity,
                              String message, int glucoseValue) {

        // Busca todos os observadores ativos para notificá-los
        List<FamilyConnection> connections = connectionRepository
                .findByMonitoredUserIdAndStatus(user.getId(), ConnectionStatus.ACTIVE);

        UUID[] notifiedUsers = connections.stream()
                .map(c -> c.getObserverUser().getId())
                .toArray(UUID[]::new);

        Alert alert = new Alert();
        alert.setUser(user);
        alert.setReading(reading);
        alert.setAlertType(type);
        alert.setSeverity(severity);
        alert.setGlucoseValue(glucoseValue);
        alert.setMessage(message);
        alert.setNotifiedUsers(notifiedUsers);

        alertRepository.save(alert);
        log.info("Alerta {} criado para usuário {} — glicemia: {} mg/dL",
                type, user.getId(), glucoseValue);
    }

    public List<Alert> getAlertsForUser(UUID userId) {
        return alertRepository.findByUserIdOrderByTriggeredAtDesc(userId);
    }

    public List<Alert> getUnreadAlerts(UUID userId) {
        return alertRepository.findUnreadByUserIdOrNotified(userId);
    }
}
