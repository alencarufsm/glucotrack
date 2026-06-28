import { Component, OnInit, signal, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DatePipe } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatChipsModule } from '@angular/material/chips';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { ApiService } from '../../core/services/api.service';
import type { FamilyConnection } from '../../core/models';

@Component({
  selector: 'app-family',
  imports: [
    FormsModule,
    DatePipe,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatInputModule,
    MatFormFieldModule,
    MatChipsModule,
    MatProgressSpinnerModule,
  ],
  templateUrl: './family.html',
  styleUrl: './family.scss',
})
export class Family implements OnInit {
  private readonly api = inject(ApiService);

  readonly loading = signal(true);
  readonly inviting = signal(false);
  readonly connections = signal<FamilyConnection[]>([]);
  readonly error = signal('');
  readonly inviteError = signal('');
  readonly inviteSuccess = signal('');
  inviteEmail = '';

  ngOnInit() {
    this.api.getFamilyConnections().subscribe({
      next: (data) => {
        this.connections.set(data);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(err.message);
        this.loading.set(false);
      },
    });
  }

  sendInvite() {
    if (!this.inviteEmail) return;
    this.inviting.set(true);
    this.inviteError.set('');
    this.inviteSuccess.set('');
    this.api.inviteFamily(this.inviteEmail).subscribe({
      next: () => {
        this.inviteSuccess.set(`Convite enviado para ${this.inviteEmail}!`);
        this.inviteEmail = '';
        this.inviting.set(false);
      },
      error: (err) => {
        this.inviteError.set(err.message ?? 'Erro ao enviar convite.');
        this.inviting.set(false);
      },
    });
  }

  getStatusLabel(status: string): string {
    return status === 'ACTIVE' ? 'Ativo' : 'Pendente';
  }

  getStatusColor(status: string): 'primary' | 'warn' {
    return status === 'ACTIVE' ? 'primary' : 'warn';
  }
}
