#!/bin/bash
TF_CMD="docker compose -f docker-compose.yml run --rm terraform"

terraform_init(){
    local TERRAFORM_ENV="$1"
    export TERRAFORM_ENV
    $TF_CMD init -upgrade
}

terraform_plan(){
    local TERRAFORM_ENV="$1"
    export TERRAFORM_ENV
    $TF_CMD plan
}


terraform_apply(){
    local TERRAFORM_ENV="$1"
    export TERRAFORM_ENV
    $TF_CMD apply -auto-approve
}

terraform_destroy(){
    local TERRAFORM_ENV="$1"
    export TERRAFORM_ENV
    $TF_CMD destroy -auto-approve
}


# Основная логика обработки аргументов
if [ $# -eq 0 ]; then
    echo "Использование: $0 <команда> [окружение]"
    echo "Доступные команды: init, plan, apply, destroy"
    echo "Пример: $0 plan proxmox"
    exit 1
fi

COMMAND="$1"
TERRAFORM_ENV="${2:-proxmox}"  # По умолчанию — proxmox, если не указано иное

case "$COMMAND" in
    "init")
        terraform_init "$TERRAFORM_ENV"
        ;;
    "plan")
        terraform_plan "$TERRAFORM_ENV"
        ;;
    "apply")
        terraform_apply "$TERRAFORM_ENV"
        ;;
    "destroy")
        terraform_destroy "$TERRAFORM_ENV"
        ;;
    *)
        echo "Неизвестная команда: $COMMAND"
        echo "Доступные команды: init, plan, apply, destroy"
        exit 1
        ;;
esac