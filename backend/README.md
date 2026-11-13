# PocketSindico backend — Node-RED + Cloudant

All features share **one Cloudant database** (`CLOUDANT_DATABASE`, default `condominio_db`).

## Setup

1. Copy `.env.example` to `.env` and fill in `CLOUDANT_URL` and `CLOUDANT_API_KEY`.
2. `docker compose up -d`, open http://localhost:1880 → ☰ → **Import** → `node-red/flows/pocketsindico_flows.json` → **Deploy**.
3. The **11 DATABASE SETUP** tab runs on start: it creates the database, the indexes and the demo data, and copies legacy "lost & found" listings into the lost-and-found module. Existing documents are never overwritten.
4. Optional: `./cloudant/load.sh` does the same database setup from the command line.
5. Postman: import the collection and environment from `postman/`, select the environment and run the collection.

When updating an existing Node-RED instance, choose **Replace** when the import dialog reports existing nodes, so routes are not duplicated.

### Environment variables

| Variable | Description |
|---|---|
| `CLOUDANT_URL` | Cloudant instance URL |
| `CLOUDANT_API_KEY` | IAM API key (the token is cached by the flow) |
| `CLOUDANT_DATABASE` | Database name (default `condominio_db`) |
| `CONDOMINIO_ID` | Condominium id (default `condominio_001`) |
| `CLOUDANT_USER` / `CLOUDANT_PASSWORD` | Optional basic auth (local CouchDB or legacy credentials); replaces the API key when set |
| `SINDICO_TELEFONE` / `PORTARIA_TELEFONE` | Optional phone numbers used by `/api/contatos` when the user has none |
| `NODE_RED_PORT` | Host port (default `1880`) |

## Flow organization

| Tab | Purpose |
|---|---|
| 00 CONFIGURATION | **CLOUDANT - REQUEST** subroutine (IAM token cache or basic auth) |
| 01 DEMO PROFILES | Demo users |
| 03 PERMISSIONS | Permission matrix, features and default favorites per role |
| 04 HOME & FAVORITES | Home screen and favorites |
| 05 ANNOUNCEMENTS | Building announcements |
| 06 LISTINGS | Resident listings, likes and comments |
| 07 BILLS | Maintenance fee bills |
| 08 CONTACTS | Building manager and front desk contacts |
| 09 PACKAGES | Packages and resident list |
| 10 DEMO DATA | Demo names and phone numbers |
| 11 DATABASE SETUP | Database, indexes, seed data and migrations |
| 12 INCIDENT REPORTS | Reports from residents to the building manager |
| 13 LOST & FOUND | Lost-and-found items |
| 14 RESERVATIONS | Shared space bookings |
| 99 ERROR LOGS | Catch-all error handler |

Every route follows the same pattern: **HTTP IN → identify user → authorize → query Cloudant → format → HTTP RESPONSE**. Database calls go through the shared `CLOUDANT - REQUEST` link-call subroutine.

## Roles and permissions

| Role (`perfil`) | Main permissions |
|---|---|
| `morador` (resident) | view announcements, create listings, view own packages and bills, book reservations, send incident reports, view lost & found |
| `guarda` (guard) | register and edit packages, register and edit lost & found, view reservations, send incident reports |
| `sindico` (building manager) | publish announcements, moderate listings, view all bills, manage packages, approve/cancel reservations, receive and reply to incident reports |

Default favorites — resident: packages, bills, reservations · guard: packages, lost & found, incident reports · manager: incident reports, announcements, packages.

## API reference

All requests send the demo user in the `X-Usuario-Id` header.

### Session and home
| Method | Route | Description |
|---|---|---|
| GET | `/api/demo/perfis` | Demo profiles |
| GET | `/api/permissoes` | Permissions of the current user |
| GET / PUT | `/api/favoritos` | Read / save favorites |
| GET | `/api/home` | User, features, favorites, latest announcement and latest package |

### Bulletin board
| Method | Route | Description |
|---|---|---|
| GET / POST | `/api/comunicados` | List / publish announcements (manager) |
| PUT / DELETE | `/api/comunicados/:id` | Edit / delete own announcement |
| GET / POST | `/api/anuncios` | List active listings (most liked first) / create listing |
| GET | `/api/anuncios/meus` | Own listings (active and closed) |
| PUT / DELETE | `/api/anuncios/:id` | Edit / delete own listing (manager may delete any) |
| PUT | `/api/anuncios/:id/encerrar` · `/reativar` | Close / reactivate own listing |
| PUT | `/api/anuncios/:id/favorito` | Toggle like |
| GET / POST | `/api/anuncios/:id/comentarios` | List / add comments |
| PUT / DELETE | `/api/anuncios/:id/comentarios/:comentarioId` | Edit / delete own comment (manager may delete any) |

Announcement categories: `avisos`, `manutencao`, `obras`, `limpeza`, `assembleias`, `seguranca`, `outro`. Listing categories: `venda`, `comida`, `roupas`, `pets`, `servicos`, `doacoes`, `outro`.

### Packages
| Method | Route | Description |
|---|---|---|
| GET | `/api/encomendas` | Residents see their own; guard and manager see all (`?status=` filter) |
| POST | `/api/encomendas` | Register (guard/manager) |
| PUT | `/api/encomendas/:id` | Edit all fields, photo and status |
| GET | `/api/moradores` | Residents available as recipients |

Status: `aguardando_retirada` (waiting for pickup) → `retirada` (picked up, stores `data_entrega`). Send `sem_destinatario: true` (or no `morador_id`) to register a package with an **unknown recipient**, optionally with `destinatario_informado` (text from the label). It stays visible only to guards and the manager until a resident is assigned.

### Bills and contacts
| Method | Route | Description |
|---|---|---|
| GET | `/api/boletos` · `/api/boletos/:id` | Resident: own bills · manager: all (guard: 403) |
| POST | `/api/demo/boletos` | Creates demo bills for the current user (idempotent) |
| GET | `/api/contatos` | Building manager and front desk with phone numbers |

### Incident reports
| Method | Route | Description |
|---|---|---|
| GET | `/api/ocorrencias` | Residents/guards: own reports · manager: all (`?etapa=aguardando\|recebido`) |
| POST | `/api/ocorrencias` | Send a report (title, description, category, location, photo) |
| PUT | `/api/ocorrencias/:id/receber` | Manager opened the report → *Received* (idempotent) |
| PUT | `/api/ocorrencias/:id/responder` | Manager reply (`resposta`) or courtesy reminder (`lembrete`) |

Status: `aguardando` (waiting) → `recebida` (received) → `respondida` (replied), with a full `historico`. Older documents with status `recebida` and no `recebida_em` are read as `aguardando`.

### Lost & found
| Method | Route | Description |
|---|---|---|
| GET | `/api/achados` | List items (`?status=`, `?categoria=`) |
| POST | `/api/achados` | Register item (guard/manager) |
| PUT | `/api/achados/:id` | Edit item and status |

Categories: `documentos`, `chaves`, `eletronicos`, `roupas`, `objetos`, `outro`. Status: `perdido` (lost) / `encontrado` (recovered).

### Reservations
| Method | Route | Description |
|---|---|---|
| GET | `/api/reservas?espaco=<id>&data=YYYY-MM-DD` | Booked slots for a space and day |
| GET | `/api/reservas/minhas` | Own reservations (manager: all upcoming) |
| POST | `/api/reservas` | Book `{espaco_id, data, horario}` (resident/manager) |
| DELETE | `/api/reservas/:id` | Cancel (owner or manager) |

Spaces: `churrasqueira`, `salao_festas`, `quadra_basquete`, `campo_futebol`, `academia`. One-hour slots from 08:00 to 20:00. Document id `reserva_<space>_<date>_<hour>` guarantees no double bookings (409).

## Data notes

- User document id: `usuario_DEMO-001`; other documents reference users as `DEMO-001`.
- Listing likes: `favanuncio_<user>_<listing>` (counted with `_find`, no mutable counters).
- Photos are stored as Base64 inside the document. Cloudant rejects documents above 1 MB, so the flows check the final document size and return **413** when needed.
- Node-RED accepts request bodies up to 5 MB by default (`apiMaxLength`).

## Security

`X-Usuario-Id` exists for demo mode only. Replace it with server-validated authentication before production, keep credentials in environment variables, and put HTTPS in front of Node-RED when exposing it outside the local network.
