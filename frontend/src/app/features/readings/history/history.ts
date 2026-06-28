import {
  Component,
  OnInit,
  OnDestroy,
  signal,
  inject,
  ElementRef,
  viewChild,
  effect,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSelectModule } from '@angular/material/select';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatChipsModule } from '@angular/material/chips';
import { Chart, registerables } from 'chart.js';
import { ApiService } from '../../../core/services/api.service';
import type { GlucoseReading, MealContext } from '../../../core/models';

Chart.register(...registerables);

const MEAL_CONTEXT_LABELS: Record<MealContext, string> = {
  FASTING: 'Jejum',
  PRE_MEAL: 'Pré-refeição',
  POST_MEAL: 'Pós-refeição',
};

@Component({
  selector: 'app-history',
  imports: [
    FormsModule,
    RouterLink,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatSelectModule,
    MatFormFieldModule,
    MatProgressSpinnerModule,
    MatChipsModule,
  ],
  templateUrl: './history.html',
  styleUrl: './history.scss',
})
export class History implements OnInit, OnDestroy {
  private readonly api = inject(ApiService);
  private chart: Chart | null = null;

  readonly chartCanvas = viewChild<ElementRef<HTMLCanvasElement>>('chartCanvas');

  readonly loading = signal(true);
  readonly readings = signal<GlucoseReading[]>([]);
  readonly error = signal('');
  selectedDays = 7;

  constructor() {
    effect(() => {
      const data = this.readings();
      const canvas = this.chartCanvas();
      if (data.length > 0 && canvas) {
        this.renderChart(data);
      }
    });
  }

  readonly dayOptions = [
    { value: 1, label: 'Hoje' },
    { value: 7, label: '7 dias' },
    { value: 14, label: '14 dias' },
    { value: 30, label: '30 dias' },
  ];

  ngOnInit() {
    this.loadReadings();
  }

  ngOnDestroy() {
    this.chart?.destroy();
  }

  loadReadings() {
    this.loading.set(true);
    this.readings.set([]);
    const to = new Date();
    const from = new Date(Date.now() - this.selectedDays * 24 * 60 * 60 * 1000);
    this.api.getReadings(from.toISOString(), to.toISOString()).subscribe({
      next: (data) => {
        this.readings.set(data);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(err.message);
        this.loading.set(false);
      },
    });
  }

  private renderChart(readings: GlucoseReading[]) {
    const canvas = this.chartCanvas()?.nativeElement;
    if (!canvas) return;

    this.chart?.destroy();

    const sorted = [...readings].sort(
      (a, b) => new Date(a.measuredAt).getTime() - new Date(b.measuredAt).getTime(),
    );

    const labels = sorted.map((r) =>
      new Date(r.measuredAt).toLocaleString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      }),
    );

    this.chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels,
        datasets: [
          {
            label: 'Glicemia (mg/dL)',
            data: sorted.map((r) => r.value),
            borderColor: '#1a237e',
            backgroundColor: 'rgba(26, 35, 126, 0.05)',
            borderWidth: 2,
            pointBackgroundColor: sorted.map((r) => this.getPointColor(r.value)),
            pointRadius: 5,
            tension: 0.3,
            fill: true,
          },
        ],
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => `${ctx.raw} mg/dL`,
            },
          },
        },
        scales: {
          y: {
            min: 40,
            grid: { color: 'rgba(0,0,0,0.05)' },
          },
        },
      },
      plugins: [
        {
          id: 'targetZone',
          beforeDraw: (chart) => {
            const { ctx, chartArea, scales } = chart;
            if (!chartArea) return;
            const y70 = scales['y'].getPixelForValue(70);
            const y180 = scales['y'].getPixelForValue(180);
            ctx.save();
            ctx.fillStyle = 'rgba(46, 125, 50, 0.08)';
            ctx.fillRect(chartArea.left, y180, chartArea.width, y70 - y180);
            ctx.restore();
          },
        },
      ],
    });
  }

  private getPointColor(value: number): string {
    if (value < 70) return '#c62828';
    if (value <= 180) return '#2e7d32';
    if (value <= 249) return '#f57f17';
    return '#c62828';
  }

  getMealLabel(ctx: MealContext): string {
    return MEAL_CONTEXT_LABELS[ctx];
  }

  getStatusClass(value: number): string {
    if (value < 70) return 'danger';
    if (value <= 180) return 'normal';
    if (value <= 249) return 'warning';
    return 'danger';
  }

  formatDateTime(iso: string): string {
    return new Date(iso).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  }
}
