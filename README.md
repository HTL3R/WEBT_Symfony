# Symfony

A starting point for students who want to build **with the Symfony framework**.

- **`src/Controller/`** — your controllers (routes live in attributes)
- **`src/Entity/`** — your Doctrine entities
- **`templates/`** — your Twig templates
- **`public/`** — the only folder reachable over HTTP

## Requirements

- [Docker](https://docs.docker.com/get-docker/) must be installed.

## Project structure

```
├── src/                 # your PHP code (controllers, entities, forms)
├── templates/           # your Twig templates
├── config/              # Symfony configuration
├── public/              # document root — only this is served (Port 80)
├── var/                 # cache, logs and the SQLite database (generated)
├── vendor/              # Composer dependencies (ships with the project)
├── .env                 # development defaults
├── Dockerfile           # PHP 8.5 + Apache image
├── docker-compose.yml   # Docker Compose configuration
├── docker-entrypoint.sh # restores vendor/, prepares var/, starts Apache
├── start.sh             # start/stop containers, run console commands
└── build.sh             # build and export images
```

The whole folder is *mapped* into the container, but only `public/` is *served*.
Those are two different things: the container can see all your files (that is why
editing them works instantly), while Apache will only ever hand out what is under
`public/`. Your source, `.env`, `config/` and the database sit outside the
document root and cannot be fetched over HTTP.

## Start the environment

```bash
./start.sh
```

- **http://localhost** → the Symfony app

Until you add your first controller, Symfony shows its welcome page.

### Where to work

**You work directly in this project folder on your own machine.** The *entire*
directory is mapped into the container:

```
your project folder  ->  /var/www/html   (inside the container)
```

So there is no separate place to put your code and nothing to copy anywhere: the
files you see here are exactly the files the web server runs. Edit `src/`,
`templates/` and `config/` right where they are.

The mapping goes both ways — files the application creates (the SQLite database,
Symfony's cache and logs in `var/`) appear in this folder too, owned by you and
editable as normal.

### Live editing

Because the folder is mapped rather than copied, **edit a file, reload the
browser, done** — no rebuild and no restart. This applies to controllers,
templates and configuration alike; the app runs in Symfony's `dev` environment,
which rebuilds its cache automatically.

You only need `./build.sh` or `./start.sh -b` when the `Dockerfile` changes.

Run in the background:

```bash
./start.sh -d
```

## Stop the environment

```bash
./start.sh -s
```

## Symfony console

Run any Symfony command inside the container with `-c`:

```bash
./start.sh -c about                      # environment overview
./start.sh -c doctrine:database:create   # create the SQLite database
./start.sh -c make:controller            # generate a controller
./start.sh -c cache:clear
```

## Further commands

| Command | Description |
|---------|-------------|
| `./start.sh -b` | Rebuild the image and start — **needs internet, do not use during the exam** |
| `./start.sh -r` | Restart the container |
| `./start.sh -l` | Show logs |
| `./start.sh -c <cmd>` | Run a Symfony console command |
| `./start.sh --status` | Show container status |

## Exam setup (no internet)

During the exam there is no internet connection, so **nothing may be built on the
exam machine**. The image is prepared in advance and only started on the day.

**Beforehand, on a machine with internet:**

```bash
./build.sh -e      # builds the image and writes _images/webt-symfony.tar
```

**On each exam machine, once, with the .tar copied over:**

```bash
docker load -i _images/webt-symfony.tar
```

**During the exam:**

```bash
./start.sh
```

That is all. `./start.sh` never builds — it uses the image that is already there
— so it works completely offline. `vendor/` does not need to be present either:
if it is missing, the container restores it on first start.

> **Do not run `./build.sh` or `./start.sh -b` during the exam.** Both rebuild the
> image, which downloads system packages and fails without internet, leaving you
> with no working environment. `start.sh` refuses `-b` for this reason; the
> refusal can be overridden with `ALLOW_BUILD=1` when you do have internet.

These commands are all safe offline: `./start.sh`, `-d`, `-s`, `-r`, `-l`,
`--status` and `-c`.

## Build and export images

Build the image (without starting it):

```bash
./build.sh
```

Clean build (without the Docker cache):

```bash
./build.sh -c
```

Build and export as a `.tar` file (to `_images/`):

```bash
./build.sh -e
```

Options can be combined:

```bash
./build.sh -c -e        # clean build and export
```

Load an exported image on another machine:

```bash
docker load -i _images/webt-symfony.tar
```

## Ports

| Service | URL |
|---------|-----|
| Symfony app | http://localhost:80 |

The port can be changed with the `HTTP_PORT` environment variable:

```bash
HTTP_PORT=8080 ./start.sh
```

## Configuration

`.env` holds the development defaults (environment, database, secret). Values in
`docker-compose.yml` take precedence over it, and both can be overridden from
the shell:

```bash
APP_ENV=prod ./start.sh
```

Put anything genuinely secret in `.env.local`, which should never be committed.

### Sample data (fixtures)

Every time the container starts, it first applies pending Doctrine migrations
and then loads the fixtures from `src/DataFixtures/`. The `LOAD_FIXTURES`
setting in `.env` decides whether that second step happens:

```dotenv
# 1 = load fixtures on every start (default), 0 = skip
LOAD_FIXTURES=1
```

- **`1`:** on each start, the tables of your entities are **emptied and
  refilled** with the fixture data. Anything you created through the app in the
  meantime is gone after a restart, so you always begin from the same known
  state.
- **`0`:** fixtures are not touched, and your data survives restarts.

After changing `LOAD_FIXTURES`, stop and start the environment again
(`./start.sh -s`, then `./start.sh`). A plain restart with `-r` keeps the old
value, because the setting is read only when the container is created. For a
single run you can also override it from the shell:

```bash
LOAD_FIXTURES=0 ./start.sh
```

Changes to your fixture *classes* take effect on the next start
(`./start.sh -r` is enough). To reload them right away without restarting:

```bash
./start.sh -c doctrine:fixtures:load
```

`docker compose logs app` shows which fixtures were loaded at startup.

## Dependencies

`vendor/` is **not** in git — `composer.lock` is. Building the image installs the
exact versions pinned in that lockfile, so every machine ends up with the same
dependencies. A fresh clone therefore builds fine; it just needs internet for
that one step.

Once built, no network is needed again: `vendor/` is baked into the image, and if
your working copy has no `vendor/` the container restores it on first start.

Composer itself is available inside the container:

```bash
docker compose exec app composer <command>
```

## Credits

Originally based on [symfony-docker](https://github.com/dunglas/symfony-docker)
by [Kévin Dunglas](https://dunglas.dev), available under the MIT License. The
FrankenPHP/Caddy runtime has been replaced with PHP 8.4 + Apache for this course.