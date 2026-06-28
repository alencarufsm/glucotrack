import { Component, signal, inject } from '@angular/core';
import { FormBuilder, Validators, ReactiveFormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { ApiService } from '../../../core/services/api.service';
import type { MealContext } from '../../../core/models';

@Component({
  selector: 'app-new-reading',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatSelectModule,
    MatIconModule,
    MatProgressSpinnerModule,
  ],
  templateUrl: './new-reading.html',
  styleUrl: './new-reading.scss',
})
export class NewReading {
  private readonly fb = inject(FormBuilder);
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);

  readonly loading = signal(false);
  readonly error = signal('');
  readonly success = signal(false);

  readonly mealContextOptions: { value: MealContext; label: string; icon: string }[] = [
    { value: 'FASTING', label: 'Jejum', icon: 'bedtime' },
    { value: 'PRE_MEAL', label: 'Pré-refeição', icon: 'restaurant' },
    { value: 'POST_MEAL', label: 'Pós-refeição', icon: 'dinner_dining' },
  ];

  readonly form = this.fb.nonNullable.group({
    value: [
      null as unknown as number,
      [Validators.required, Validators.min(20), Validators.max(600)],
    ],
    measuredAt: [this.nowLocalDatetime(), Validators.required],
    mealContext: ['FASTING' as MealContext, Validators.required],
    notes: [''],
  });

  private nowLocalDatetime(): string {
    const now = new Date();
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
    return now.toISOString().slice(0, 16);
  }

  getGlucoseClass(value: number | null): string {
    if (!value) return '';
    if (value < 70) return 'value--danger';
    if (value <= 180) return 'value--normal';
    if (value <= 249) return 'value--warning';
    return 'value--danger';
  }

  getGlucoseLabel(value: number | null): string {
    if (!value) return '';
    if (value < 54) return '⚠️ Hipoglicemia severa';
    if (value < 70) return '⚠️ Hipoglicemia';
    if (value <= 99) return '✅ Normal (jejum)';
    if (value <= 125) return '⚡ Pré-diabetes';
    if (value <= 180) return '✅ Dentro da meta';
    if (value <= 249) return '⚠️ Hiperglicemia';
    return '🚨 Hiperglicemia severa';
  }

  async onSubmit() {
    if (this.form.invalid) return;
    this.loading.set(true);
    this.error.set('');
    try {
      const { value, measuredAt, mealContext, notes } = this.form.getRawValue();
      const measuredAtUtc = new Date(measuredAt).toISOString();
      this.api
        .createReading({ value, measuredAt: measuredAtUtc, mealContext, notes: notes || undefined })
        .subscribe({
          next: () => {
            this.success.set(true);
            setTimeout(() => this.router.navigate(['/readings']), 1500);
          },
          error: (err) => {
            this.error.set(err.message ?? 'Erro ao salvar medição.');
            this.loading.set(false);
          },
        });
    } catch {
      this.loading.set(false);
    }
  }
}
