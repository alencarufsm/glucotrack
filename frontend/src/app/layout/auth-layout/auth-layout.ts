import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-auth-layout',
  imports: [RouterOutlet],
  template: `
    <div class="auth-container">
      <div class="auth-brand">
        <span class="auth-brand__icon">💉</span>
        <h1 class="auth-brand__name">GlicoTrack</h1>
        <p class="auth-brand__tagline">Monitore. Entenda. Cuide.</p>
      </div>
      <div class="auth-card">
        <router-outlet />
      </div>
    </div>
  `,
  styleUrl: './auth-layout.scss',
})
export class AuthLayout {}
