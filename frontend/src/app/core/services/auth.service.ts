import { Injectable, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import { Session } from '@supabase/supabase-js';
import { SupabaseService } from './supabase.service';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly _session = signal<Session | null>(null);

  readonly session = this._session.asReadonly();
  readonly isAuthenticated = computed(() => this._session() !== null);
  readonly accessToken = computed(() => this._session()?.access_token ?? null);
  readonly currentUser = computed(() => this._session()?.user ?? null);

  constructor(
    private supabase: SupabaseService,
    private router: Router,
  ) {
    this.supabase.getSession().then((session) => this._session.set(session));

    this.supabase.onAuthStateChange((session) => {
      this._session.set(session);
      if (!session) {
        this.router.navigate(['/login']);
      }
    });
  }

  async login(email: string, password: string): Promise<void> {
    const { error } = await this.supabase.signIn(email, password);
    if (error) throw error;
    await this.router.navigate(['/dashboard']);
  }

  async register(email: string, password: string, name: string): Promise<void> {
    const { error } = await this.supabase.signUp(email, password, name);
    if (error) throw error;
  }

  async logout(): Promise<void> {
    await this.supabase.signOut();
    await this.router.navigate(['/login']);
  }
}
