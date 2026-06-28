import { Component, signal, inject } from '@angular/core';
import { FormBuilder, Validators, ReactiveFormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSelectModule } from '@angular/material/select';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { AuthService } from '../../../core/services/auth.service';
import type { DiabetesType } from '../../../core/models';

@Component({
  selector: 'app-register',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatSelectModule,
    MatProgressSpinnerModule,
  ],
  templateUrl: './register.html',
  styleUrl: './register.scss',
})
export class Register {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);

  readonly loading = signal(false);
  readonly error = signal('');
  readonly success = signal(false);
  readonly hidePassword = signal(true);

  readonly diabetesOptions: { value: DiabetesType; label: string }[] = [
    { value: 'PREDIABETES', label: 'Pré-diabetes' },
    { value: 'TYPE_1', label: 'Diabetes Tipo 1' },
    { value: 'NONE', label: 'Sem diagnóstico / Familiar observador' },
  ];

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    diabetesType: ['NONE' as DiabetesType, Validators.required],
  });

  async onSubmit() {
    if (this.form.invalid) return;
    this.loading.set(true);
    this.error.set('');
    try {
      const { name, email, password } = this.form.getRawValue();
      await this.auth.register(email, password, name);
      this.success.set(true);
    } catch (err: any) {
      this.error.set(err.message ?? 'Erro ao cadastrar. Tente novamente.');
    } finally {
      this.loading.set(false);
    }
  }
}
