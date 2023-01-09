![Docker pulls](https://img.shields.io/docker/pulls/atareao/mariadb-backup)

# mariadb-backup

Backup MariaDB to the local filesystem with periodic rotating backups, based on [prodrigestivill/postgres-backup-local]().
Backup multiple databases from the same host by setting the database names in `MARIADB_DB` separated by commas or spaces.

Supports the following Docker architectures: `linux/amd64`, `linux/arm64`.

Please consider reading detailed the [How the backups folder works?](#how-the-backups-folder-works).

## Usage


Docker Compose:

```yaml
version: '3.8'

services:
  mariabd:
    container_name: mariadb
    image: mariadb:latest
    init: true
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ejemplo
      MYSQL_USER: usuario
      MYSQL_PASSWORD: contraseña
      MYSQL_ROOT_PASSWORD: mypass
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - internal
    logging:
      driver: journald
  phpmyadmin:
    image: phpmyadmin
    container_name: phpmyadmin
    restart: always
    networks:
      - internal
    ports:
      - 8080:80
    environment:
      - PMA_ARBITRARY=1
    logging:
      driver: journald
  backup:
    image: atareao/mariadb-backup:latest
    container_name: backup
    init: true
    restart: unless-stopped
    networks:
      - internal
    volumes:
      - ./hooks:/hooks
      - ./backup:/backup
    environment:
      MARIADB_DB: ejemplo
      MARIADB_HOST: mariadb
      MARIADB_PORT: 3306
      MARIADB_USER: usuario
      MARIADB_PASSWORD: contraseña
      SCHEDULE: "* * 1/24 * * * *"
      BACKUP_KEEP_MINS: 1440
      BACKUP_KEEP_DAYS: 7
      BACKUP_KEEP_WEEKS: 4
      BACKUP_KEEP_MONTHS: 6

volumes:
  mariadb_data: {}
networks:
  internal: {}
```

### Environment Variables

| env variable | description |
|--|--|
| BACKUP_DIR | Directory to save the backup at. Defaults to `/backup`. |
| BACKUP_SUFFIX | Filename suffix to save the backup. Defaults to `.sql.gz`. |
| BACKUP_KEEP_DAYS | Number of daily backups to keep before removal. Defaults to `7`. |
| BACKUP_KEEP_WEEKS | Number of weekly backups to keep before removal. Defaults to `4`. |
| BACKUP_KEEP_MONTHS | Number of monthly backups to keep before removal. Defaults to `6`. |
| BACKUP_KEEP_MINS | Number of minutes for `last` folder backups to keep before removal. Defaults to `1440`. |
| MARIADB_DB | Comma or space separated list of postgres databases to backup. Required. |
| MARIADB_HOST | MariaDB connection parameter; postgres host to connect to. Required. |
| MARIADB_PASSWORD | MariaDB connection parameter; postgres password to connect with. Required. |
| MARIADB_PORT | MariaDB connection parameter; postgres port to connect to. Defaults to `3306`. |
| MARIADB_USER | MariaDB connection parameter; postgres user to connect with. Required. |
| SCHEDULE | [tokio-cron-scheduler](https://docs.rs/crate/tokio-cron-scheduler/latest) specifying the interval between postgres backups. Defaults to `0 0 */24 * * * *`. |
| WEBHOOK_URL | URL to be called after an error or after a successful backup (POST with a JSON payload, check `hooks/00-webhook` file for more info). Default disabled. |
| WEBHOOK_EXTRA_ARGS | Extra arguments for the `curl` execution in the webhook (check `hooks/00-webhook` file for more info). |

#### Special Environment Variables

This variables are not intended to be used for normal deployment operations:

### How the backups folder works?

First a new backup is created in the `last` folder with the full time.

Once this backup finish succefully then, it is hard linked (instead of coping to avoid use more space) to the rest of the folders (daily, weekly and monthly). This step replaces the old backups for that category storing always only the latest for each category (so the monthly backup for a month is always storing the latest for that month and not the first).

So the backup folder are structured as follows:

* `BACKUP_DIR/last/DB-YYYYMMDD-HHmmss.sql.gz`: all the backups are stored separatly in this folder.
* `BACKUP_DIR/daily/DB-YYYYMMDD.sql.gz`: always store (hard link) the **latest** backup of that day.
* `BACKUP_DIR/weekly/DB-YYYYww.sql.gz`: always store (hard link) the **latest** backup of that week (the last day of the week will be Sunday as it uses ISO week numbers).
* `BACKUP_DIR/monthly/DB-YYYYMM.sql.gz`: always store (hard link) the **latest** backup of that month (normally the ~31st).

And the following symlinks are also updated after each successfull backup for simlicity:

```
BACKUP_DIR/last/DB-latest.sql.gz -> BACKUP_DIR/last/DB-YYYYMMDD-HHmmss.sql.gz
BACKUP_DIR/daily/DB-latest.sql.gz -> BACKUP_DIR/daily/DB-YYYYMMDD.sql.gz
BACKUP_DIR/weekly/DB-latest.sql.gz -> BACKUP_DIR/weekly/DB-YYYYww.sql.gz
BACKUP_DIR/monthly/DB-latest.sql.gz -> BACKUP_DIR/monthly/DB-YYYYMM.sql.gz
```

For **cleaning** the script removes the files for each category only if the new backup has been successfull.
To do so it is using the following independent variables:

* BACKUP_KEEP_MINS: will remove files from the `last` folder that are older than its value in minutes after a new successfull backup without affecting the rest of the backups (because they are hard links).
* BACKUP_KEEP_DAYS: will remove files from the `daily` folder that are older than its value in days after a new successfull backup.
* BACKUP_KEEP_WEEKS: will remove files from the `weekly` folder that are older than its value in weeks after a new successfull backup (remember that it starts counting from the end of each week not the beggining).
* BACKUP_KEEP_MONTHS: will remove files from the `monthly` folder that are older than its value in months (of 31 days) after a new successfull backup (remember that it starts counting from the end of each month not the beggining).

### Hooks

The folder `hooks` inside the container can contain hooks/scripts to be run in differrent cases getting the exact situation as a first argument (`error`, `pre-backup` or `post-backup`).

Just create an script in that folder with execution permission so that [run-parts](https://manpages.debian.org/stable/debianutils/run-parts.8.en.html) can execute it on each state change.

Please, as an example take a look in the script already present there that implements the `WEBHOOK_URL` functionality.

### Manual Backups

By default this container makes daily backups, but you can start a manual backup by running `/backup.sh`.

This script as example creates one backup as the running user and saves it the working folder.

```sh
```
## Restore examples

Some examples to restore/apply the backups.

### Restore using a new container

Replace `$BACKUPFILE`, `$VERSION`, `$HOSTNAME`, `$PORT`, `$USERNAME` and `$DBNAME` from the following command:

```sh
```
