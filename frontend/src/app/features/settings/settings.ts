import { Component, OnInit, signal, inject } from '@angular/core';
import { FormBuilder, Validators, ReactiveFormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatRadioModule } from '@angular/material/radio';
import { DatePipe } from '@angular/common';
import { AuthService } from '../../core/services/auth.service';
import { ApiService } from '../../core/services/api.service';
import type { DiabetesType, LibreLinkStatus, LibreLinkPatient } from '../../core/models';

@Component({
  selector: 'app-settings',
  imports: [
    ReactiveFormsModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatProgressSpinnerModule,
    MatRadioModule,
    DatePipe,
  ],
  templateUrl: './settings.html',
  styleUrl: './settings.scss',
})
export class Settings implements OnInit {
  private readonly fb = inject(FormBuilder);
  readonly auth = inject(AuthService);
  private readonly api = inject(ApiService);

  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly saveSuccess = signal(false);
  readonly error = signal('');

  // FreeStyle Libre
  readonly libreStatus = signal<LibreLinkStatus | null>(null);
  readonly libreTesting = signal(false);
  readonly libreSyncing = signal(false);
  readonly libreError = signal('');
  readonly librePatients = signal<LibreLinkPatient[]>([]);
  selectedPatient: LibreLinkPatient | null = null;
  librePasswordVisible = false;

  readonly libreForm = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', Validators.required],
  });

  readonly diabetesOptions: { value: DiabetesType; label: string; description: string }[] = [
    { value: 'TYPE_1', label: 'Diabetes Tipo 1', description: 'Requer insulina, monitoramento intensivo' },
    { value: 'PREDIABETES', label: 'Pré-diabetes', description: 'Glicemia em jejum entre 100–125 mg/dL' },
    { value: 'NONE', label: 'Familiar observador', description: 'Acompanha dados de outra pessoa' },
  ];

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    birthDate: [''],
    diabetesType: ['NONE' as DiabetesType, Validators.required],
    weight: [null as number | null, [Validators.min(20), Validators.max(300)]],
    physicalLimitations: [''],
    targetMin: [70, [Validators.required, Validators.min(40), Validators.max(200)]],
    targetMax: [180, [Validators.required, Validators.min(80), Validators.max(400)]],
  });

  ngOnInit() {
    this.api.getLibreLinkStatus().subscribe({
      next: (s) => this.libreStatus.set(s),
    });

    this.api.getProfile().subscribe({
      next: (profile) => {
        this.form.patchValue({
          name: profile.name,
          birthDate: profile.birthDate ?? '',
          diabetesType: profile.diabetesType,
          weight: profile.weight ?? null,
          physicalLimitations: profile.physicalLimitations ?? '',
          targetMin: profile.targetMin,
          targetMax: profile.targetMax,
        });
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  save() {
    if (this.form.invalid) return;
    this.saving.set(true);
    this.saveSuccess.set(false);
    this.error.set('');
    const { name, birthDate, diabetesType, weight, physicalLimitations, targetMin, targetMax } = this.form.getRawValue();
    this.api.updateProfile({
      name,
      birthDate: birthDate || undefined,
      diabetesType,
      weight: weight ?? undefined,
      physicalLimitations: physicalLimitations || undefined,
      targetMin,
      targetMax,
    }).subscribe({
      next: () => {
        this.saving.set(false);
        this.saveSuccess.set(true);
        setTimeout(() => this.saveSuccess.set(false), 3000);
      },
      error: (err) => {
        this.error.set(err.message ?? 'Erro ao salvar.');
        this.saving.set(false);
      },
    });
  }

  logout() {
    this.auth.logout();
  }

  testLibreCredentials() {
    if (this.libreForm.invalid) return;
    this.libreTesting.set(true);
    this.libreError.set('');
    this.librePatients.set([]);
    this.selectedPatient = null;
    const { email, password } = this.libreForm.getRawValue();
    this.api.testLibreLinkCredentials(email, password).subscribe({
      next: (res) => {
        this.libreTesting.set(false);
        if (res.patients.length === 0) {
          this.libreError.set('Nenhum paciente vinculado. Ative o LibreLink Up na conta do paciente.');
          return;
        }
        this.librePatients.set(res.patients);
        if (res.patients.length === 1) this.selectedPatient = res.patients[0];
      },
      error: (err) => {
        this.libreTesting.set(false);
        this.libreError.set(err.error?.message ?? 'Credenciais inválidas ou erro de conexão.');
      },
    });
  }

  saveLibreConfig() {
    if (!this.selectedPatient) return;
    const { email, password } = this.libreForm.getRawValue();
    this.api.configureLibreLink(email, password, this.selectedPatient.patientId, this.selectedPatient.displayName).subscribe({
      next: (status) => {
        this.libreStatus.set(status);
        this.librePatients.set([]);
        this.libreForm.reset();
      },
      error: (err) => this.libreError.set(err.error?.message ?? 'Erro ao salvar configuração.'),
    });
  }

  syncLibre() {
    this.libreSyncing.set(true);
    this.libreError.set('');
    this.api.syncLibreLink().subscribe({
      next: (res) => {
        this.libreSyncing.set(false);
        this.api.getLibreLinkStatus().subscribe({ next: (s) => this.libreStatus.set(s) });
        this.libreError.set(res.synced > 0
          ? `${res.synced} leituras sincronizadas com sucesso.`
          : 'Nenhuma leitura nova encontrada.');
      },
      error: (err) => {
        this.libreSyncing.set(false);
        this.libreError.set(err.error?.message ?? 'Erro ao sincronizar.');
      },
    });
  }

  disconnectLibre() {
    this.api.disconnectLibreLink().subscribe({
      next: () => this.libreStatus.set({ connected: false, patientName: null, lastSync: null }),
    });
  }
}
