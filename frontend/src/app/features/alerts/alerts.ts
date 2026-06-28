import { Component, OnInit, signal, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatChipsModule } from '@angular/material/chips';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { ApiService } from '../../core/services/api.service';
import type { Alert, AlertType } from '../../core/models';

const ALERT_CONFIG: Record<AlertType, { icon: string; label: string; color: string }> = {
  HYPOGLYCEMIA: { icon: 'arrow_downward', label: 'Hipoglicemia', color: '#c62828' },
  HYPERGLYCEMIA: { icon: 'arrow_upward', label: 'Hiperglicemia', color: '#f57f17' },
  RAPID_FALL: { icon: 'trending_down', label: 'Queda rápida', color: '#c62828' },
  RAPID_RISE: { icon: 'trending_up', label: 'Subida rápida', color: '#f57f17' },
  REMINDER: { icon: 'notifications', label: 'Lembrete', color: '#1a237e' },
};

@Component({
  selector: 'app-alerts',
  imports: [DatePipe, MatCardModule, MatIconModule, MatChipsModule, MatProgressSpinnerModule],
  templateUrl: './alerts.html',
  styleUrl: './alerts.scss',
})
export class Alerts implements OnInit {
  private readonly api = inject(ApiService);

  readonly loading = signal(true);
  readonly alerts = signal<Alert[]>([]);
  readonly error = signal('');

  ngOnInit() {
    this.api.getAlerts().subscribe({
      next: (data) => {
        this.alerts.set(data);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(err.message);
        this.loading.set(false);
      },
    });
  }

  getAlertConfig(type: AlertType) {
    return ALERT_CONFIG[type];
  }
}
