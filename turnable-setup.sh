#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#  Turnable Client — установка и настройка для Android (Termux)
# ============================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/Turnable"
LISTEN_ADDR="127.0.0.1:5080"
BASH_BIN="$(which bash)"

print_step() { echo -e "\n${CYAN}[$1/$TOTAL_STEPS]${NC} $2"; }
print_ok()   { echo -e "${GREEN}  OK:${NC} $1"; }
print_warn() { echo -e "${YELLOW}  !:${NC} $1"; }
print_err()  { echo -e "${RED}  ОШИБКА:${NC} $1"; }

echo ""
echo "========================================"
echo "  Turnable Client — установка для Android"
echo "========================================"
echo ""

TOTAL_STEPS=6

# ─── Шаг 1: Проверка окружения ───
print_step 1 "Проверка окружения..."

if [ ! -d "/data/data/com.termux" ]; then
    print_err "Этот скрипт предназначен только для Termux на Android"
    exit 1
fi
print_ok "Termux обнаружен"
print_ok "Bash: $BASH_BIN"

ARCH=$(uname -m)
case "$ARCH" in
    aarch64)       BIN_ARCH="arm64" ;;
    armv7l|armv8l) BIN_ARCH="arm" ;;
    x86_64)        BIN_ARCH="amd64" ;;
    i386|i686)     BIN_ARCH="386" ;;
    *)
        print_err "Неизвестная архитектура: $ARCH"
        exit 1
        ;;
esac
print_ok "Архитектура: $ARCH ($BIN_ARCH)"

mkdir -p "$INSTALL_DIR"
print_ok "Папка: $INSTALL_DIR"

# ─── Шаг 2: Получить бинарник ───
print_step 2 "Получение Turnable..."

if [ -f "$INSTALL_DIR/turnable" ]; then
    echo -e "  Turnable уже установлен."
    echo -n "  Переустановить? (д/н): "
    read -r REINSTALL
    if [[ "$REINSTALL" != "д" && "$REINSTALL" != "y" ]]; then
        print_ok "Оставляю текущую версию"
        SKIP_DOWNLOAD=1
    fi
fi

if [ -z "$SKIP_DOWNLOAD" ]; then
    echo ""
    echo "  Как получить файл Turnable?"
    echo "  1) Скачать с GitHub (нужен доступ к GitHub)"
    echo "  2) У меня уже есть файл на телефоне (скачал через ВК/Telegram)"
    echo ""
    echo -n "  Выбери (1 или 2): "
    read -r DL_METHOD

    if [ "$DL_METHOD" = "1" ]; then
        echo "  Скачиваю turnable-android-$BIN_ARCH ..."
        if curl --fail --progress-bar -L -o "$INSTALL_DIR/turnable" \
            "https://github.com/TheAirBlow/Turnable/releases/latest/download/turnable-android-$BIN_ARCH"; then
            chmod +x "$INSTALL_DIR/turnable"
            print_ok "Скачан и установлен"
        else
            print_err "Не удалось скачать. Нет доступа к GitHub?"
            print_warn "Скачай файл вручную и запусти скрипт снова (вариант 2)"
            exit 1
        fi
    else
        echo ""
        echo "  Где лежит файл? Варианты:"
        echo "    a) ~/storage/downloads/  (папка Загрузки)"
        echo "    b) Указать путь вручную"
        echo ""

        if [ ! -d "$HOME/storage" ]; then
            print_warn "Нужен доступ к хранилищу телефона"
            termux-setup-storage
            sleep 3
        fi

        echo "  Ищу файлы turnable в Загрузках..."
        FOUND_FILES=$(find "$HOME/storage/downloads" -name "turnable*" 2>/dev/null | head -5)

        if [ -n "$FOUND_FILES" ]; then
            echo -e "  ${GREEN}Найдены файлы:${NC}"
            i=1
            declare -a FILE_LIST
            while IFS= read -r f; do
                echo "    $i) $(basename "$f")"
                FILE_LIST[$i]="$f"
                ((i++))
            done <<< "$FOUND_FILES"
            echo "    $i) Указать путь вручную"
            echo ""
            echo -n "  Выбери номер: "
            read -r FILE_NUM

            if [ "$FILE_NUM" -lt "$i" ] 2>/dev/null && [ "$FILE_NUM" -gt 0 ]; then
                CHOSEN="${FILE_LIST[$FILE_NUM]}"
            else
                echo -n "  Введи полный путь к файлу: "
                read -r CHOSEN
            fi
        else
            print_warn "Файлы не найдены в Загрузках"
            echo -n "  Введи полный путь к файлу: "
            read -r CHOSEN
        fi

        if [ ! -f "$CHOSEN" ]; then
            print_err "Файл не найден: $CHOSEN"
            exit 1
        fi

        cp "$CHOSEN" "$INSTALL_DIR/turnable"
        chmod +x "$INSTALL_DIR/turnable"
        print_ok "Файл скопирован: $(basename "$CHOSEN")"
    fi
fi

if ! "$INSTALL_DIR/turnable" --help >/dev/null 2>&1; then
    print_err "Бинарник не работает. Возможно, неправильная архитектура."
    print_warn "Твоя архитектура: $ARCH — нужен файл turnable-android-$BIN_ARCH"
    exit 1
fi
print_ok "Turnable работает"

# ─── Шаг 3: Настройка конфигурации ───
print_step 3 "Настройка конфигурации..."

CONFIG_FILE="$INSTALL_DIR/wireguard.txt"

if [ -f "$CONFIG_FILE" ]; then
    echo "  Конфиг уже есть: $(cat "$CONFIG_FILE" | head -c 60)..."
    echo -n "  Заменить? (д/н): "
    read -r REPLACE_CFG
    if [[ "$REPLACE_CFG" != "д" && "$REPLACE_CFG" != "y" ]]; then
        print_ok "Оставляю текущий конфиг"
        SKIP_CONFIG=1
    fi
fi

if [ -z "$SKIP_CONFIG" ]; then
    echo ""
    echo "  Вставь URL конфигурации от сервера Turnable."
    echo "  Он выглядит как: turnable://uuid:call@vk.com/wg?pub_key=...&type=relay&..."
    echo ""
    echo "  (Получить его можно на сервере командой:"
    echo "   ./turnable config generate UUID ROUTE)"
    echo ""
    echo -n "  URL: "
    read -r CONFIG_URL

    if [ -z "$CONFIG_URL" ]; then
        print_err "URL не может быть пустым"
        exit 1
    fi

    if [[ "$CONFIG_URL" != turnable://* ]]; then
        print_warn "URL не начинается с turnable:// — возможно ошибка"
        echo -n "  Продолжить всё равно? (д/н): "
        read -r FORCE
        if [[ "$FORCE" != "д" && "$FORCE" != "y" ]]; then
            exit 1
        fi
    fi

    echo "$CONFIG_URL" > "$CONFIG_FILE"
    print_ok "Конфиг сохранён"
fi

# ─── Шаг 4: Создание скриптов ───
print_step 4 "Создание скриптов запуска..."

cat > "$INSTALL_DIR/start.sh" << STARTEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
LISTEN="127.0.0.1:5080"
CONFIG="wireguard.txt"

if [ ! -f "turnable" ]; then
    echo "ОШИБКА: файл turnable не найден в \$(pwd)"
    exit 1
fi
if [ ! -f "\$CONFIG" ]; then
    echo "ОШИБКА: файл \$CONFIG не найден в \$(pwd)"
    exit 1
fi

pkill -f "turnable client" 2>/dev/null
sleep 1

echo "Запускаю Turnable на \$LISTEN ..."
CONFIG_URL=\$(cat "\$CONFIG")
./turnable client -l "\$LISTEN" "\$CONFIG_URL"
STARTEOF
chmod +x "$INSTALL_DIR/start.sh"

cat > "$INSTALL_DIR/start-bg.sh" << BGEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
LISTEN="127.0.0.1:5080"
CONFIG="wireguard.txt"
LOG="turnable.log"

if [ ! -f "turnable" ]; then
    echo "ОШИБКА: файл turnable не найден"
    exit 1
fi
if [ ! -f "\$CONFIG" ]; then
    echo "ОШИБКА: файл \$CONFIG не найден"
    exit 1
fi

pkill -f "turnable client" 2>/dev/null
sleep 1

CONFIG_URL=\$(cat "\$CONFIG")
nohup ./turnable client -l "\$LISTEN" -i "\$CONFIG_URL" > "\$LOG" 2>&1 &
PID=\$!
sleep 2

if kill -0 \$PID 2>/dev/null; then
    echo "Turnable запущен (PID: \$PID)"
    echo "Порт: \$LISTEN"
    echo "Логи: \$(pwd)/\$LOG"
    echo "\$PID" > turnable.pid
else
    echo "ОШИБКА: Turnable не запустился"
    echo "Последние логи:"
    tail -20 "\$LOG" 2>/dev/null
    exit 1
fi
BGEOF
chmod +x "$INSTALL_DIR/start-bg.sh"

cat > "$INSTALL_DIR/stop.sh" << STOPEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
if [ -f "turnable.pid" ]; then
    PID=\$(cat "turnable.pid")
    kill "\$PID" 2>/dev/null
    rm "turnable.pid"
fi
pkill -f "turnable client" 2>/dev/null
echo "Turnable остановлен"
STOPEOF
chmod +x "$INSTALL_DIR/stop.sh"

cat > "$INSTALL_DIR/status.sh" << STATEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
if pgrep -f "turnable client" >/dev/null 2>&1; then
    PID=\$(pgrep -f "turnable client" | head -1)
    echo "Turnable РАБОТАЕТ (PID: \$PID)"
    echo "Последние логи:"
    tail -5 "turnable.log" 2>/dev/null
else
    echo "Turnable НЕ запущен"
fi
STATEOF
chmod +x "$INSTALL_DIR/status.sh"

print_ok "Создано: start.sh, start-bg.sh, stop.sh, status.sh"

# ─── Шаг 5: Виджеты для домашнего экрана ───
print_step 5 "Настройка виджетов (Termux:Widget)..."

mkdir -p "$HOME/.shortcuts"

cat > "$HOME/.shortcuts/VPN-ON.sh" << WONEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
${BASH_BIN} start-bg.sh
echo ""
echo "Теперь включи WireGuard в NekoBox"
am start -n moe.nb4a/.ui.MainActivity 2>/dev/null
echo ""
echo "Нажми Enter чтобы закрыть это окно"
read
WONEOF
chmod +x "$HOME/.shortcuts/VPN-ON.sh"

cat > "$HOME/.shortcuts/VPN-OFF.sh" << WOFFEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
${BASH_BIN} stop.sh
echo "Не забудь отключить NekoBox"
echo ""
echo "Нажми Enter чтобы закрыть"
read
WOFFEOF
chmod +x "$HOME/.shortcuts/VPN-OFF.sh"

cat > "$HOME/.shortcuts/VPN-STATUS.sh" << WSTEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
${BASH_BIN} status.sh
echo ""
echo "Нажми Enter чтобы закрыть"
read
WSTEOF
chmod +x "$HOME/.shortcuts/VPN-STATUS.sh"

print_ok "Виджеты созданы: VPN-ON, VPN-OFF, VPN-STATUS"
print_warn "Добавь виджет Termux:Widget на домашний экран"

# ─── Шаг 6: Автозапуск при загрузке ───
print_step 6 "Автозапуск при включении телефона (Termux:Boot)..."

echo "  Хочешь чтобы Turnable запускался при включении телефона?"
echo "  (нужен Termux:Boot)"
echo -n "  Настроить? (д/н): "
read -r SETUP_BOOT

if [[ "$SETUP_BOOT" == "д" || "$SETUP_BOOT" == "y" ]]; then
    mkdir -p "$HOME/.termux/boot"

    cat > "$HOME/.termux/boot/start-turnable.sh" << BOOTEOF
#!${BASH_BIN}
sleep 15
cd "$INSTALL_DIR"
pkill -f "turnable client" 2>/dev/null
CONFIG_URL=\$(cat wireguard.txt)
nohup ./turnable client -l 127.0.0.1:5080 -i "\$CONFIG_URL" > turnable.log 2>&1 &
BOOTEOF
    chmod +x "$HOME/.termux/boot/start-turnable.sh"

    print_ok "Автозапуск настроен"
    print_warn "Не забудь открыть Termux:Boot хотя бы раз"
else
    print_ok "Пропущено"
fi

# ─── Итог ───
echo ""
echo "========================================"
echo -e "  ${GREEN}Установка завершена!${NC}"
echo "========================================"
echo ""
echo "  Файлы: $INSTALL_DIR/"
echo "  ├── turnable        — ядро"
echo "  ├── wireguard.txt   — конфиг"
echo "  ├── start.sh        — запуск (с логами в терминале)"
echo "  ├── start-bg.sh     — запуск в фоне"
echo "  ├── stop.sh         — остановка"
echo "  └── status.sh       — проверка статуса"
echo ""
echo "  ─── Как использовать ───"
echo ""
echo "  В Termux:"
echo "    cd ~/Turnable && bash start.sh     # с логами"
echo "    cd ~/Turnable && bash start-bg.sh  # в фоне"
echo "    cd ~/Turnable && bash stop.sh      # остановить"
echo "    cd ~/Turnable && bash status.sh    # статус"
echo ""
echo "  С домашнего экрана:"
echo "    Кнопка VPN-ON    — запустить"
echo "    Кнопка VPN-OFF   — остановить"
echo "    Кнопка VPN-STATUS — проверить"
echo ""
echo "  ─── Порядок включения VPN ───"
echo ""
echo "  1. Запусти Turnable (кнопка или bash start.sh)"
echo "  2. Подожди ~10 секунд"
echo "  3. Включи WireGuard в NekoBox"
echo ""
echo "  ─── Первый запуск ───"
echo ""
echo "  При первом запуске нужно пройти капчу ВК."
echo "  Инструкция появится в логах."
echo ""
echo "========================================"
