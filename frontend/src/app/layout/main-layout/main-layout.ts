import { Component, signal, inject } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { AuthService } from '../../core/services/auth.service';

const NAV_ITEMS = [
  { path: '/dashboard', icon: 'dashboard', label: 'Painel' },
  { path: '/readings', icon: 'monitor_heart', label: 'Histórico' },
  { path: '/readings/new', icon: 'add_circle', label: 'Nova Medição' },
  { path: '/family', icon: 'group', label: 'Família' },
  { path: '/alerts', icon: 'notifications', label: 'Alertas' },
  { path: '/settings', icon: 'settings', label: 'Configurações' },
];

@Component({
  selector: 'app-main-layout',
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    MatToolbarModule,
    MatSidenavModule,
    MatListModule,
    MatIconModule,
    MatButtonModule,
    MatMenuModule,
  ],
  templateUrl: './main-layout.html',
  styleUrl: './main-layout.scss',
})
export class MainLayout {
  readonly auth = inject(AuthService);
  readonly navItems = NAV_ITEMS;
  readonly sidenavOpen = signal(true);

  get userName(): string {
    const user = this.auth.currentUser();
    return user?.user_metadata?.['name'] ?? user?.email ?? 'Usuário';
  }

  toggleSidenav() {
    this.sidenavOpen.update((v) => !v);
  }

  logout() {
    this.auth.logout();
  }
}
