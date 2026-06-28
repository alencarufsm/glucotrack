import { Component, OnInit, signal, inject } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatChipsModule } from '@angular/material/chips';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import type { GlucoseStats, GlucoseReading } from '../../core/models';

@Component({
  selector: 'app-dashboard',
  imports: [
    DecimalPipe,
    RouterLink,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatProgressBarModule,
    MatProgressSpinnerModule,
    MatChipsModule,
  ],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss',
})
export class Dashboard implements OnInit {
  private readonly api = inject(ApiService);
  readonly auth = inject(AuthService);

  readonly loading = signal(true);
  readonly stats = signal<GlucoseStats | null>(null);
  readonly recentReadings = signal<GlucoseReading[]>([]);
  readonly error = signal('');

  get userName(): string {
    const user = this.auth.currentUser();
    return user?.user_metadata?.['name']?.split(' ')[0] ?? 'usuário';
  }

  ngOnInit() {
    this.loadData();
  }

  private loadData() {
    this.loading.set(true);
    this.api.getStats(14).subscribe({
      next: (stats) => this.stats.set(stats),
      error: (err) => this.error.set(err.message),
    });

    const to = new Date().toISOString();
    const from = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    this.api.getReadings(from, to).subscribe({
      next: (readings) => {
        this.recentReadings.set(readings.slice(0, 5));
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  getGlucoseStatus(value: number): 'danger' | 'warning' | 'normal' | 'high' {
    if (value < 70) return 'danger';
    if (value <= 180) return 'normal';
    if (value <= 249) return 'warning';
    return 'danger';
  }

  getGlucoseLabel(value: number): string {
    if (value < 54) return 'Hipoglicemia severa';
    if (value < 70) return 'Hipoglicemia';
    if (value <= 99) return 'Normal';
    if (value <= 125) return 'Pré-diabetes';
    if (value <= 180) return 'Meta Tipo 1';
    if (value <= 249) return 'Hiperglicemia';
    return 'Hiperglicemia severa';
  }

  formatTime(isoString: string): string {
    return new Date(isoString).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  }
}
