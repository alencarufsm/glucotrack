import { Injectable } from '@angular/core';
import { createClient, SupabaseClient, Session, User } from '@supabase/supabase-js';
import { environment } from '../../../environments/environment';

@Injectable({ providedIn: 'root' })
export class SupabaseService {
  readonly client: SupabaseClient;

  constructor() {
    this.client = createClient(environment.supabaseUrl, environment.supabaseAnonKey);
  }

  get auth() {
    return this.client.auth;
  }

  async signIn(email: string, password: string) {
    return this.client.auth.signInWithPassword({ email, password });
  }

  async signUp(email: string, password: string, name: string) {
    return this.client.auth.signUp({
      email,
      password,
      options: { data: { name } },
    });
  }

  async signOut() {
    return this.client.auth.signOut();
  }

  async getSession(): Promise<Session | null> {
    const { data } = await this.client.auth.getSession();
    return data.session;
  }

  onAuthStateChange(callback: (session: Session | null) => void) {
    return this.client.auth.onAuthStateChange((_, session) => callback(session));
  }
}
