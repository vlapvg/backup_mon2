#!/bin/bash

# Загрузка учебных баз данных на MySQL source сервер


set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Загрузка учебных баз данных на MySQL сервер ===${NC}"

# Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ошибка: Скрипт должен запускаться с правами root${NC}"
    exit 1
fi

# Проверка запуска MySQL
if ! systemctl is-active --quiet mysql; then
    echo -e "${YELLOW}MySQL служба не запущена. Пытаюсь запустить...${NC}"
    systemctl start mysql
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось запустить MySQL${NC}"
        exit 1
    fi
    sleep 3
fi

# Массив с именами баз данных
DATABASES=("scomp" "ship" "spain")
SQL_FILES=("scomp.sql" "ship.sql" "spain.sql")

# Функция для выполнения MySQL команд
mysql_exec() {
    mysql -e "$1"
    return $?
}

# Функция для импорта SQL файла
import_sql() {
    local db_name=$1
    local sql_file=$2
    
    echo -e "${BLUE}Импорт $sql_file в базу $db_name...${NC}"
    
    if [ ! -f "$sql_file" ]; then
        echo -e "${YELLOW}Файл $sql_file не найден. Пропускаем...${NC}"
        return 1
    fi
    
    if mysql "$db_name" < "$sql_file"; then
        echo -e "${GREEN}✓ Успешно импортирован $sql_file${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибка импорта $sql_file${NC}"
        return 1
    fi
}

# Создаем и импортируем базы
for i in "${!DATABASES[@]}"; do
    DB_NAME="${DATABASES[$i]}"
    SQL_FILE="${SQL_FILES[$i]}"
    
    echo -e "\n${GREEN}--- Обработка базы: $DB_NAME ---${NC}"
    
    # Проверяем существование базы
    if mysql -e "USE $DB_NAME" 2>/dev/null; then
        echo -e "${YELLOW}База $DB_NAME уже существует.${NC}"
        read -p "Перезаписать базу? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Удаление старой базы $DB_NAME..."
            mysql -e "DROP DATABASE IF EXISTS $DB_NAME;"
            echo "Создание новой базы $DB_NAME..."
            mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            import_sql "$DB_NAME" "$SQL_FILE"
        else
            echo -e "${YELLOW}Пропускаем базу $DB_NAME${NC}"
        fi
    else
        echo "Создание базы $DB_NAME..."
        mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        import_sql "$DB_NAME" "$SQL_FILE"
    fi
done

# Предоставляем права пользователю repl на новые базы
echo -e "\n${GREEN}--- Настройка прав пользователя repl ---${NC}"
for DB_NAME in "${DATABASES[@]}"; do
    echo "Предоставление прав на базу $DB_NAME..."
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO 'repl'@'%';"
done

mysql -e "FLUSH PRIVILEGES;"

# Проверка созданных баз
echo -e "\n${GREEN}=== Проверка результатов ===${NC}"
echo "Список баз данных:"
mysql -e "SHOW DATABASES;" | grep -E "^($(IFS=\|; echo "${DATABASES[*]}"))$" || true

echo -e "\n${GREEN}=== Проверка таблиц в базах ===${NC}"
for DB_NAME in "${DATABASES[@]}"; do
    if mysql -e "USE $DB_NAME" 2>/dev/null; then
        TABLE_COUNT=$(mysql -e "USE $DB_NAME; SHOW TABLES;" | wc -l)
        echo "База $DB_NAME: $TABLE_COUNT таблиц"
    fi
done

echo -e "\n${GREEN}=== Проверка прав пользователя repl ===${NC}"
mysql -e "SHOW GRANTS FOR 'repl'@'%';"

echo -e "\n${GREEN}=== Загрузка учебных баз завершена успешно! ===${NC}"
echo "Базы данных: ${DATABASES[*]} готовы к использованию."