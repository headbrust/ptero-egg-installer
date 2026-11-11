# ptero-egg-installer

One-command tool to **download** (and optionally **import**) the main generic eggs into your [Pterodactyl](https://pterodactyl.io) panel.

Includes:

| Egg | Runtime |
|-----|---------|
| Python Generic | Python 3.7 – 3.13 |
| Generic Java | Java 8, 11, 16, 17, 19, 21 |
| Node.js Generic | Node runtimes from yolks |

Sources: [pterodactyl/generic-eggs](https://github.com/pterodactyl/generic-eggs)

---

## Quick start (download only)

```bash
curl -fsSL https://raw.githubusercontent.com/headbrust/ptero-egg-installer/main/install-eggs.sh -o install-eggs.sh
chmod +x install-eggs.sh
./install-eggs.sh
```

Eggs are saved to `./eggs/`. Then in the panel:

1. **Admin → Nests** (create a nest e.g. `Generic` if needed)
2. **Import Egg** → upload each `.json` from `./eggs/`

---

## One-liner download

```bash
curl -fsSL https://raw.githubusercontent.com/headbrust/ptero-egg-installer/main/install-eggs.sh | bash
```

---

## Import via API (Panel 2.x)

Create a **Client API key** as a **root admin**:

**Admin → Account → API Credentials** → create key (starts with `ptlc_`)

```bash
export PANEL_URL="https://panel.example.com"
export API_KEY="ptlc_xxxxxxxx"

./install-eggs.sh --import
```

This posts each egg to `POST /api/admin/eggs/import`.

> **Panel 1.x:** API egg import is limited. Prefer download + UI **Import Egg** under Nests. The script still downloads all files for you.

---

## Options

```text
./install-eggs.sh              # download to ./eggs
./install-eggs.sh --import     # download + API import
./install-eggs.sh --out /tmp/eggs
./install-eggs.sh --list
./install-eggs.sh --help
```

---

## After import

Generic eggs use placeholder startup detection (`change this text` / `change this part`).

Edit each egg → **Configuration / Startup** and set the "done" string to something your app actually prints (e.g. `Bot is ready`), or servers stay stuck on **Starting**.

---

## Requirements

- `curl`, `bash`
- Optional: `python3` (pretty-prints import response name)
- For `--import`: Panel reachable from the machine running the script + root admin Client API key

---

## License

MIT — eggs themselves belong to their upstream authors (Parker / ptero-eggs / generic-eggs).
