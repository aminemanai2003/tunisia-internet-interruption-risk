# Data boundary

The restricted World Bank Enterprise Surveys panel belongs locally at
`data/raw/wbes/Tunisia_2013_2020_2024.dta`. Official INT reports downloaded by
the network-context collector are stored under `data/raw/network/`. Everything
under `data/raw/` is ignored by Git except directory placeholders.

The repository publishes only aggregate, disclosure-screened tables and figures
under `artifacts/public/`. Public-source downloads are represented by URL,
collection timestamp, byte size and SHA-256 checksum in the source manifest.
