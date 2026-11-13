# Cloudant seed data

The **11 DATABASE SETUP** tab in Node-RED does all of this automatically on start. To do it by hand:

1. Create the database: `PUT {CLOUDANT_URL}/condominio_db`
2. Insert the documents: `POST {CLOUDANT_URL}/condominio_db/_bulk_docs` with the body of `seeds/_bulk_docs.json`
3. Create each index: `POST {CLOUDANT_URL}/condominio_db/_index` with each file in `indexes/`

Or run `./cloudant/load.sh` from the `backend/` folder with `CLOUDANT_URL` and `CLOUDANT_API_KEY` set.

`sample-documents/` shows one example of each document type.

## Id conventions

| Document | `_id` |
|---|---|
| User | `usuario_DEMO-001` (other documents reference it as `DEMO-001`) |
| Favorites | `favoritos_<user>` |
| Listing like | `favanuncio_<user>_<listing>` (counted with `_find`, no mutable counters) |
| Bill | `boleto_<user>_<YYYY-MM>` |
| Reservation | `reserva_<space>_<date>_<hour>` (a second booking for the same slot gets 409) |
