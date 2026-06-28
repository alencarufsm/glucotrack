import { Routes } from '@angular/router';
import { authGuard, guestGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },

  {
    path: '',
    loadComponent: () =>
      import('./layout/auth-layout/auth-layout').then((m) => m.AuthLayout),
    canActivate: [guestGuard],
    children: [
      {
        path: 'login',
        loadComponent: () =>
          import('./features/auth/login/login').then((m) => m.Login),
      },
      {
        path: 'register',
        loadComponent: () =>
          import('./features/auth/register/register').then((m) => m.Register),
      },
    ],
  },

  {
    path: '',
    loadComponent: () =>
      import('./layout/main-layout/main-layout').then((m) => m.MainLayout),
    canActivate: [authGuard],
    children: [
      {
        path: 'dashboard',
        loadComponent: () =>
          import('./features/dashboard/dashboard').then((m) => m.Dashboard),
      },
      {
        path: 'readings',
        loadComponent: () =>
          import('./features/readings/history/history').then((m) => m.History),
      },
      {
        path: 'readings/new',
        loadComponent: () =>
          import('./features/readings/new-reading/new-reading').then((m) => m.NewReading),
      },
      {
        path: 'family',
        loadComponent: () =>
          import('./features/family/family').then((m) => m.Family),
      },
      {
        path: 'alerts',
        loadComponent: () =>
          import('./features/alerts/alerts').then((m) => m.Alerts),
      },
      {
        path: 'settings',
        loadComponent: () =>
          import('./features/settings/settings').then((m) => m.Settings),
      },
    ],
  },

  { path: '**', redirectTo: 'dashboard' },
];
