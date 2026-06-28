import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { environment } from '../../../environments/environment';
import {
  GlucoseReading,
  GlucoseStats,
  NewReadingRequest,
  FamilyConnection,
  Alert,
  User,
  LibreLinkStatus,
  LibreLinkTestResponse,
  LibreLinkSyncResponse,
} from '../models';

@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(AuthService);
  private readonly base = environment.apiUrl;

  private headers(): HttpHeaders {
    const token = this.auth.accessToken();
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  // Perfil
  getProfile(): Observable<User> {
    return this.http.get<User>(`${this.base}/api/users/me`, { headers: this.headers() });
  }

  updateProfile(data: Partial<User>): Observable<User> {
    return this.http.put<User>(`${this.base}/api/users/me`, data, { headers: this.headers() });
  }

  // Leituras de glicemia
  getReadings(from?: string, to?: string): Observable<GlucoseReading[]> {
    let url = `${this.base}/api/readings`;
    const params: string[] = [];
    if (from) params.push(`from=${from}`);
    if (to) params.push(`to=${to}`);
    if (params.length) url += `?${params.join('&')}`;
    return this.http.get<GlucoseReading[]>(url, { headers: this.headers() });
  }

  createReading(reading: NewReadingRequest): Observable<GlucoseReading> {
    return this.http.post<GlucoseReading>(`${this.base}/api/readings`, reading, {
      headers: this.headers(),
    });
  }

  getStats(days = 14): Observable<GlucoseStats> {
    return this.http.get<GlucoseStats>(`${this.base}/api/readings/stats?days=${days}`, {
      headers: this.headers(),
    });
  }

  // Família
  getFamilyConnections(): Observable<FamilyConnection[]> {
    return this.http.get<FamilyConnection[]>(`${this.base}/api/family`, {
      headers: this.headers(),
    });
  }

  inviteFamily(email: string): Observable<FamilyConnection> {
    return this.http.post<FamilyConnection>(
      `${this.base}/api/family/invite`,
      { email },
      { headers: this.headers() },
    );
  }

  acceptInvite(connectionId: string): Observable<FamilyConnection> {
    return this.http.post<FamilyConnection>(
      `${this.base}/api/family/${connectionId}/accept`,
      {},
      { headers: this.headers() },
    );
  }

  // Leituras de familiar monitorado
  getFamilyReadings(monitoredUserId: string, from?: string, to?: string): Observable<GlucoseReading[]> {
    let url = `${this.base}/api/family/${monitoredUserId}/readings`;
    const params: string[] = [];
    if (from) params.push(`from=${from}`);
    if (to) params.push(`to=${to}`);
    if (params.length) url += `?${params.join('&')}`;
    return this.http.get<GlucoseReading[]>(url, { headers: this.headers() });
  }

  // Alertas
  getAlerts(): Observable<Alert[]> {
    return this.http.get<Alert[]>(`${this.base}/api/alerts`, { headers: this.headers() });
  }

  // FreeStyle Libre — LibreLink Up
  getLibreLinkStatus(): Observable<LibreLinkStatus> {
    return this.http.get<LibreLinkStatus>(`${this.base}/api/integrations/librelink/status`, {
      headers: this.headers(),
    });
  }

  testLibreLinkCredentials(email: string, password: string): Observable<LibreLinkTestResponse> {
    return this.http.post<LibreLinkTestResponse>(
      `${this.base}/api/integrations/librelink/test`,
      { email, password },
      { headers: this.headers() },
    );
  }

  configureLibreLink(
    email: string,
    password: string,
    patientId: string,
    patientName: string,
  ): Observable<LibreLinkStatus> {
    return this.http.post<LibreLinkStatus>(
      `${this.base}/api/integrations/librelink/configure`,
      { email, password, patientId, patientName },
      { headers: this.headers() },
    );
  }

  syncLibreLink(): Observable<LibreLinkSyncResponse> {
    return this.http.post<LibreLinkSyncResponse>(
      `${this.base}/api/integrations/librelink/sync`,
      {},
      { headers: this.headers() },
    );
  }

  disconnectLibreLink(): Observable<void> {
    return this.http.delete<void>(`${this.base}/api/integrations/librelink`, {
      headers: this.headers(),
    });
  }
}
