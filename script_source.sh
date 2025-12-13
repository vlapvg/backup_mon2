#!/bin/bash

# Настройка мастера для MySQL репликации, скрипт для source сервера


set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Настройка MySQL Master для репликации ===${NC}"

# Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ошибка: Скрипт должен запускаться с правами root${NC}"
    exit 1
fi

# Проверка установки MySQL
if ! systemctl is-active --quiet mysql; then
    echo -e "${YELLOW}Предупреждение: MySQL служба не запущена${NC}"
    read -p "Запустить MySQL? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl start mysql
    else
        echo -e "${RED}MySQL должен быть запущен для настройки репликации${NC}"
        exit 1
    fi
fi

# Функция выполнения MySQL команд
execute_mysql() {
    mysql -e "$1"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка выполнения MySQL команды${NC}"
        exit 1
    fi
}

echo "Создание пользователя для репликации..."
execute_mysql "CREATE USER IF NOT EXISTS repl@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'oTUSlave#2020';"

echo "Назначение прав репликации..."
execute_mysql "GRANT REPLICATION SLAVE ON *.* TO repl@'%';"

echo "Применение изменений..."
execute_mysql "FLUSH PRIVILEGES;"

# Показать статус мастера
echo -e "\n${GREEN}Статус мастера:${NC}"
master_status=$(mysql -e "SHOW MASTER STATUS\G")
if [ -n "$master_status" ]; then
    echo "$master_status"
else
    echo -e "${YELLOW}Не удалось получить статус мастера${NC}"
fi

# Показать созданного пользователя
echo -e "\n${GREEN}Проверка пользователя repl:${NC}"
mysql -e "SELECT user, host FROM mysql.user WHERE user='repl';"

echo -e "\n${GREEN}=== Настройка мастера завершена успешно ===${NC}"
echo -e "Пожалуйста, запишите значения File и Position из 'SHOW MASTER STATUS'"
echo -e "Они понадобятся для настройки реплики"
