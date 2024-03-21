#!/bin/sh
set -eo

HOOKS_DIR="/hooks"
BACKUP_DIR=${BACKUP_DIR:-/cronitab/backup}
BACKUP_SUFFIX=${BACKUP_SUFFIX:-.sql.gz}
KEEP_MINS=${BACKUP_KEEP_MINS:-1440}
KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}
BACKUP_KEEP_WEEKS=${BACKUP_KEEP_WEEKS:-4}
BACKUP_KEEP_MONTHS=${BACKUP_KEEP_MONTHS:-7}
MARIADB_PORT=${MARIADB_PORT:-3306}
if [ -d "${HOOKS_DIR}" ]; then
    on_error(){
      run-parts -a "error" "${HOOKS_DIR}"
    }
    trap 'on_error' ERR
fi

if [ -z "${MARIADB_DB}" ]; then
    echo "You need to set the MARIADB_DB."
    exit 1
fi

if [ -z "${MARIADB_HOST}" ]; then
    echo "You need to set the MARIADB_HOST environment variable."
    exit 1
fi

if [ -z "${MARIADB_USER}" ]; then
    echo "You need to set the MARIADB_USER."
    exit 1
fi

if [ -z "${MARIADB_PASSWORD}" ]; then
    echo "You need to set the MARIADB_PASSWORD environment variable or link to a container named MARIADB."
    exit 1
fi

#Process vars
MARIADB_DBS=$(echo "${MARIADB_DB}" | tr , " ")

KEEP_MINS=${BACKUP_KEEP_MINS}
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=$(((BACKUP_KEEP_WEEKS * 7) + 1))
KEEP_MONTHS=$(((BACKUP_KEEP_MONTHS * 31) + 1))

# Pre-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "pre-backup" --exit-on-error "${HOOKS_DIR}"
fi

#Initialize dirs
mkdir -p "${BACKUP_DIR}/last"
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly"
mkdir -p "${BACKUP_DIR}/monthly"

# Print date
echo "=== Doing backup at $(date) ==="

#Loop all databases
for DB in ${MARIADB_DBS}; do
    #Initialize filename vers
    LAST_FILENAME="${DB}-$(date +%Y%m%d-%H%M%S)${BACKUP_SUFFIX}"
    DAILY_FILENAME="${DB}-$(date +%Y%m%d)${BACKUP_SUFFIX}"
    WEEKLY_FILENAME="${DB}-$(date +%G%V)${BACKUP_SUFFIX}"
    MONTHY_FILENAME="${DB}-$(date +%Y%m)${BACKUP_SUFFIX}"
    FILE="${BACKUP_DIR}/last/${LAST_FILENAME}"
    DFILE="${BACKUP_DIR}/daily/${DAILY_FILENAME}"
    WFILE="${BACKUP_DIR}/weekly/${WEEKLY_FILENAME}"
    MFILE="${BACKUP_DIR}/monthly/${MONTHY_FILENAME}"
    #Create dump
    echo "Creating cluster dump of ${DB} database from ${MARIADB_HOST}..."
    mysqldump --host="$MARIADB_HOST" \
              --port="$MARIADB_PORT" \
              --user="$MARIADB_USER" \
              --password="$MARIADB_PASSWORD" \
              "$DB" | gzip > "$FILE"
    #Copy (hardlink) for each entry
    if [ -d "${FILE}" ]; then
        DFILENEW="${DFILE}-new"
        WFILENEW="${WFILE}-new"
        MFILENEW="${MFILE}-new"
        rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
        mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
        ln -f "${FILE}/"* "${DFILENEW}/"
        ln -f "${FILE}/"* "${WFILENEW}/"
        ln -f "${FILE}/"* "${MFILENEW}/"
        rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
        echo "Replacing daily backup ${DFILE} folder this last backup..."
        mv "${DFILENEW}" "${DFILE}"
        echo "Replacing weekly backup ${WFILE} folder this last backup..."
        mv "${WFILENEW}" "${WFILE}"
        echo "Replacing monthly backup ${MFILE} folder this last backup..."
        mv "${MFILENEW}" "${MFILE}"
    else
        echo "Replacing daily backup ${DFILE} file this last backup..."
        ln -vf "${FILE}" "${DFILE}"
        echo "Replacing weekly backup ${WFILE} file this last backup..."
        ln -vf "${FILE}" "${WFILE}"
        echo "Replacing monthly backup ${MFILE} file this last backup..."
        ln -vf "${FILE}" "${MFILE}"
    fi
    # Update latest symlinks
    echo "Point last backup file to this last backup..."
    ln -svf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest daily backup to this last backup..."
    ln -svf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest weekly backup to this last backup..."
    ln -svf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest monthly backup to this last backup..."
    ln -svf "${MONTHY_FILENAME}" "${BACKUP_DIR}/monthly/${DB}-latest${BACKUP_SUFFIX}"
    #Clean old files
    echo "Cleaning older files for ${DB} database from ${MARIADB_HOST}..."
    find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
done

echo "SQL backup created successfully"

# Post-backup hook
if [ -d "${HOOKS_DIR}" ]; then
    run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
fi
