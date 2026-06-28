# GlicoTrack

App de monitoramento de glicemia para pessoas com diabetes e pré-diabetes, com painel familiar com análise inteligente.

## Estrutura do projeto

```
glucotrack/
├── backend/        # API REST — Java Spring Boot
├── frontend/       # Painel web — Angular 18
├── mobile/         # App mobile — Flutter
├── supabase/
│   └── migrations/ # Scripts SQL do banco de dados
└── .github/
    └── workflows/  # CI/CD automático
```

## Stack

| Camada | Tecnologia |
|---|---|
| Backend API | Java 21 + Spring Boot 3.3 |
| Frontend Web | Angular 18 |
| Mobile | Flutter |
| Banco de dados | Supabase (PostgreSQL) |
| Autenticação | Supabase Auth |
| Tempo real | Supabase Realtime |
| Versionamento | GitHub |

## Documento de premissas

Ver [PROJECT.md](../PROJECT.md) para o documento completo de requisitos e premissas.

## Como rodar localmente

> Instruções detalhadas serão adicionadas conforme o projeto avança.

### Pré-requisitos
- Java 21
- Maven 3.9+
- Node.js 20+
- Flutter 3.24+
