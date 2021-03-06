#!/bin/bash

# default values
export PGREQUIRESSL=0
export PGSSLMODE=allow
export PGSSLROOTCERT=certs/server-ca.pem
export PGSSLCERT=certs/client-cert.pem
export PGSSLKEY=certs/client-key.pem

export SRC_HOST=db01
export SRC_PORT=5432
export SRC_USER=postgres
export SRC_PASS=certs/src_pgpass
export SRC_DB_NAME=test

export DEST_HOST=db02
export DEST_PORT=5432
export DEST_USER=postgres
export DEST_PASS=certs/dest_pgpass
export DEST_DB_NAME=test

export EXTRA_FLAGS="--no-owner --no-acl --no-password"

set -e

function help {
	echo "Read the script for necessary flags"
	echo "Here's an example execution: "
	echo -e " $ ./migrate_bdr_to_postgres.sh \\
		 --sslrootcert [root certification for destination host] \\
		 --sslcert [certificate for destination host] \\
		 --sslkey [certificate key for destination host] \\
		 -sh [source host] \\
		 -sp [source port] \\
		 -dh [destination host] \\
		 -dp [destination port] \\
		 -sw [source PGPASS file] \\
		 -dw [destination PGPASS file] \\
		 -su [source user] \\
		 -du [destination user] \\
		 -sd [source dbname] \\
		 -dd [destination dbname]"
	exit 0
}

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		--sslrootcert)
		export PGSSLROOTCERT="$2"
		shift
		shift
		;;
		--sslcert)
		export PGSSLCERT="$2"
		shift
		shift
		;;
		--sslkey)
		export PGSSLKEY="$2"
		shift
		shift
		;;
		--lock)
		export LOCK_SRC_DB=true
		shift
		shift
		;;
		-sd|--source-db)
		export SRC_DB_NAME="$2"
		shift
		shift
		;;
		-sh|--source-host)
		export SRC_HOST="$2"
		shift
		shift
		;;
		-sp|--source-port)
		export SRC_PORT="$2"
		shift
		shift
		;;
		-su|--source-user)
		export SRC_USER="$2"
		shift
		shift
		;;
		-sw|--source-pass)
		export SRC_PASS="$2"
		shift
		shift
		;;
		-dd|--dest-db)
		export DEST_DB_NAME="$2"
		shift
		shift
		;;
		-dh|--dest-host)
		export DEST_HOST="$2"
		shift
		shift
		;;
		-dp|--dest-port)
		export DEST_PORT="$2"
		shift
		shift
		;;
		-du|--dest-user)
		export DEST_USER="$2"
		shift
		shift
		;;
		-dw|--dest-pass)
		export DEST_PASS="$2"
		shift
		shift
		;;
		-h|--help)
		help
		shift
		;;
		*)
		echo "Unknown option $1"
		exit 1
		;;
	esac
done


function verify_files_hosts {
	for file in ${PGSSLROOTCERT} ${PGSSLCERT} ${PGSSLKEY} ${DEST_PASS} ${SRC_PASS}; do
		if [ ! -f ${file} ]; then
			echo "${file} does not exist but should!"
			exit 1
		fi
	done

	echo "-- Testing hosts' connectivity"
	if ! pg_isready -h ${SRC_HOST} -p ${SRC_PORT} || ! pg_isready -h ${DEST_HOST} -p ${DEST_PORT}; then
		echo "One of the hosts isn't accessible!"
		exit 1
	fi
}

function lock_db {
	LIST_FILE=${1}
	DUMP_FILE=${2}

	echo "-- Checking processes on database"
	PGPASSFILE=${SRC_PASS} psql \
						-h ${SRC_HOST} \
						-p ${SRC_PORT} \
						-U ${SRC_USER} -w \
						-d ${SRC_DB_NAME} \
						<< EOF
SELECT usename,application_name,client_addr,backend_start,state \
	FROM pg_stat_activity \
	WHERE datname = '${SRC_DB_NAME}';
EOF

	read -p "Proceed with terminating existing connections and locking out the database? " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
		echo "-- Exiting"
		exit 0
	fi

	echo "-- Locking out the database and setting connection limit to 1"
	PGPASSFILE=${SRC_PASS} psql \
						-h ${SRC_HOST} \
						-p ${SRC_PORT} \
						-U ${SRC_USER} -w \
						-d ${SRC_DB_NAME} \
						<< EOF
UPDATE pg_database \
	SET datallowconn = false, \
		datconnlimit = '1' \
	WHERE datname = '${SRC_DB_NAME}';
SELECT pg_terminate_backend(pid) \
	FROM pg_stat_activity \
	WHERE datname = '${SRC_DB_NAME}' \
		AND pid <> pg_backend_pid(); \
UPDATE pg_database \
	SET datallowconn = true \
	WHERE datname = '${SRC_DB_NAME}';
EOF
}

function dump_db {
	LIST_FILE=${1}
	DUMP_FILE=${2}

	echo "-- Running dump command"
	PGPASSFILE=${SRC_PASS} pg_dump \
						-h ${SRC_HOST} \
						-p ${SRC_PORT} \
						-U ${SRC_USER} \
						-Fc \
						${SRC_DB_NAME} \
						${EXTRA_FLAGS} \
					> ${DUMP_FILE}
}

function sanitize_dump {
	LIST_FILE=${1}
	DUMP_FILE=${2}

	echo "-- Setting up TOC"
	pg_restore --list ${DUMP_FILE} | sed -e 's/.*EXTENSION/;&/g' \
						-e 's/.*TABLE DATA bdr/;&/g' \
						-e 's/.*SECURITY LABEL/;&/g' \
					> ${LIST_FILE}
}

function prepare_dest {
	LIST_FILE=${1}
	DUMP_FILE=${2}

	echo "-- Creating database on destination host"
	PGPASSFILE=${DEST_PASS} createdb \
						-h ${DEST_HOST} \
						-p ${DEST_PORT} \
						-U ${DEST_USER} -w \
					${DEST_DB_NAME}

	echo "-- Creating needed extensions on destination database"
	for extension in $(grep "EXTENSION -" ${LIST_FILE} | sed -e 's/^.* - //' | grep -v bdr); do
		echo "-- Creating extension: $extension"
		PGPASSFILE=${DEST_PASS} psql \
						-h ${DEST_HOST} \
						-p ${DEST_PORT} \
						-U ${DEST_USER} -w \
						-d ${DEST_DB_NAME} \
						<< EOF
CREATE EXTENSION ${extension};
EOF
	done
}

function restore_dump {
	LIST_FILE=${1}
	DUMP_FILE=${2}

	echo "-- Running restore command"
	PGPASSFILE=${DEST_PASS} pg_restore \
						-h ${DEST_HOST} \
						-p ${DEST_PORT} \
						-U ${DEST_USER} \
						--use-list ${LIST_FILE} \
						${DUMP_FILE} \
						${EXTRA_FLAGS} \
						--dbname=${DEST_DB_NAME}
}

function migrate_db {
	echo "-- Running on database: ${SRC_DB_NAME}"

	LIST_FILE=/tmp/${SRC_DB_NAME}_dump.custom.list
	DUMP_FILE=/tmp/${SRC_DB_NAME}_dump.custom

	for file in ${LIST_FILE} ${DUMP_FILE}; do
		if [ -f ${file} ]; then
			echo "${file} exists but should not!"
			exit 1
		fi
	done

	if [ "$LOCK_SRC_DB" = true ]; then
		lock_db ${LIST_FILE} ${DUMP_FILE}
	fi

	dump_db ${LIST_FILE} ${DUMP_FILE}
	sanitize_dump ${LIST_FILE} ${DUMP_FILE}
	prepare_dest ${LIST_FILE} ${DUMP_FILE}
	restore_dump ${LIST_FILE} ${DUMP_FILE}

	echo "Done migrating ${SRC_DB_NAME}!"
}

verify_files_hosts
migrate_db
