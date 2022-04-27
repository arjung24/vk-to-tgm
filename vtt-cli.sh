#!/bin/bash

cli_help() {
    cli_name=${0##*/}
    echo "
vk-to-tgm CLI
Usage: ./$cli_name [command]
Commands:
  receiver, r               Run callback receiver
  bot, b                    Run Telegram bot
  wall_worker, ww           Run Celery wall worker
  playlist_worker, pw       Run Celery playlist worker
  dbcleanup_worker, dw      Run Celery db cleanup worker
  local_tunnel, lt          Run local tunnel
  sign_in, s                Create VK tokens and Telegram sessions
  upd_locale, ul            Update locales
  *                         Help
"
    exit 1
}

venv() {
    if [ -d .venv ]; then
        if command -v python3 &> /dev/null; then
            # shellcheck source=/dev/null
            source .venv/bin/activate
        else
            echo "Python3 not installed!" || exit 1
        fi
    else
        if command -v poetry &> /dev/null; then
            poetry install
            # shellcheck source=/dev/null
            source .venv/bin/activate
        elif command -v python3 &> /dev/null; then
            python3 -m venv .venv
            # shellcheck source=/dev/null
            source .venv/bin/activate
            python3 -m pip install wheel
            python3 -m pip install -r requirements.txt
        else
            echo "Python3 not installed!" || exit 1
        fi
    fi
}

case $1 in
    receiver|r)
        venv
        uvicorn app.main:app --port 8000 --reload --log-config app/logging_config.yaml
        ;;
    bot|b)
        venv
        python3 -m app.bot.main
        ;;
    wall_worker|ww)
        venv
        celery -A app.celery_worker worker -n vtt-worker-wall@%%h -Q vtt-wall --pool=solo --loglevel=INFO
        ;;
    playlist_worker|pw)
        venv
        celery -A app.celery_worker worker -n vtt-worker-pl@%%h -Q vtt-playlist --pool=solo --loglevel=INFO
        ;;
    dbcleanup_worker|dw)
        venv
        celery -A app.celery_worker worker -B -n vtt-worker-dbc@%%h -Q celery --pool=solo --loglevel=INFO
        ;;
    local_tunnel|lt)
        cd tunnel/ || exit 1
        if [ ! -f node_modules/localtunnel/localtunnel.js ]; then
            npm install
        fi
        npm start
        ;;
    sign_in|s)
        venv
        python3 -m app.sign_in
        ;;
    upd_locale|ul)
        venv
        pybabel extract --mapping babel.cfg -o locale/base.pot app/
        pybabel update -l en -i locale/base.pot -D vtt -d locale/
        pybabel update -l ru -i locale/base.pot -D vtt -d locale/
        pybabel compile -D vtt -d locale/
        ;;
    *)
        cli_help
esac