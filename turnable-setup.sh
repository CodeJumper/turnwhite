#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#  Turnable Client — установка и настройка для Android (Termux)
# ============================================================

# Гарантируем чтение с клавиатуры даже при curl | bash
[ ! -t 0 ] && exec < /dev/tty

set -e

INSTALL_DIR="$HOME/Turnable"
BASH_BIN="/data/data/com.termux/files/usr/bin/bash"

ask() {
    printf "%s" "$1"
    read REPLY
}

echo ""
echo "========================================"
echo "  Turnable Client — установка для Android"
echo "========================================"
echo ""

TOTAL=6

# ─── Шаг 1: Проверка окружения ───
echo ""
echo "[$((STEP=1))/$TOTAL] Проверка окружения..."

if [ ! -d "/data/data/com.termux" ]; then
    echo "  ОШИБКА: Только для Termux на Android"
    exit 1
fi
echo "  OK: Termux обнаружен"

ARCH=$(uname -m)
case "$ARCH" in
    aarch64)       BIN_ARCH="arm64" ;;
    armv7l|armv8l) BIN_ARCH="arm" ;;
    x86_64)        BIN_ARCH="amd64" ;;
    i386|i686)     BIN_ARCH="386" ;;
    *)             echo "  ОШИБКА: Неизвестная архитектура: $ARCH"; exit 1 ;;
esac
echo "  OK: Архитектура: $ARCH ($BIN_ARCH)"

mkdir -p "$INSTALL_DIR"

# ─── Шаг 2: Получить бинарник ───
echo ""
echo "[$((STEP=2))/$TOTAL] Получение Turnable..."

SKIP_DOWNLOAD=""
if [ -f "$INSTALL_DIR/turnable" ]; then
    echo "  Turnable уже установлен."
    ask "  Переустановить? (д/н): "
    case "$REPLY" in
        д|y) ;;
        *)   echo "  OK: Оставляю текущую версию"; SKIP_DOWNLOAD=1 ;;
    esac
fi

if [ -z "$SKIP_DOWNLOAD" ]; then
    echo ""
    echo "  Как получить файл Turnable?"
    echo "  1) Скачать с GitHub (нужен доступ к GitHub)"
    echo "  2) У меня уже есть файл на телефоне (скачал через ВК/Telegram)"
    echo ""
    ask "  Выбери (1 или 2): "

    if [ "$REPLY" = "1" ]; then
        echo "  Скачиваю turnable-android-$BIN_ARCH ..."
        if curl --fail --progress-bar -L -o "$INSTALL_DIR/turnable" \
            "https://github.com/TheAirBlow/Turnable/releases/latest/download/turnable-android-$BIN_ARCH"; then
            chmod +x "$INSTALL_DIR/turnable"
            echo "  OK: Скачан и установлен"
        else
            echo "  ОШИБКА: Не удалось скачать. Нет доступа к GitHub?"
            exit 1
        fi
    else
        if [ ! -d "$HOME/storage" ]; then
            echo "  Нужен доступ к хранилищу телефона..."
            termux-setup-storage
            sleep 3
        fi

        echo "  Ищу файлы turnable в Загрузках..."
        FOUND=""
        NUM=0
        for f in $(find "$HOME/storage/downloads" -name "turnable*" 2>/dev/null | head -5); do
            NUM=$((NUM + 1))
            echo "    $NUM) $(basename "$f")"
            eval "FILE_$NUM=\"$f\""
            FOUND=1
        done

        if [ -n "$FOUND" ]; then
            echo "    $((NUM + 1))) Указать путь вручную"
            echo ""
            ask "  Выбери номер: "
            if [ "$REPLY" -le "$NUM" ] 2>/dev/null && [ "$REPLY" -gt 0 ] 2>/dev/null; then
                eval "CHOSEN=\$FILE_$REPLY"
            else
                ask "  Введи полный путь к файлу: "
                CHOSEN="$REPLY"
            fi
        else
            echo "  Файлы не найдены в Загрузках"
            ask "  Введи полный путь к файлу: "
            CHOSEN="$REPLY"
        fi

        if [ ! -f "$CHOSEN" ]; then
            echo "  ОШИБКА: Файл не найден: $CHOSEN"
            exit 1
        fi

        cp "$CHOSEN" "$INSTALL_DIR/turnable"
        chmod +x "$INSTALL_DIR/turnable"
        echo "  OK: Файл скопирован"
    fi
fi

if ! "$INSTALL_DIR/turnable" --help >/dev/null 2>&1; then
    echo "  ОШИБКА: Бинарник не работает. Нужен turnable-android-$BIN_ARCH"
    exit 1
fi
echo "  OK: Turnable работает"

# ─── Шаг 3: Настройка конфигурации ───
echo ""
echo "[$((STEP=3))/$TOTAL] Настройка конфигурации..."

CONFIG_FILE="$INSTALL_DIR/wireguard.txt"
SKIP_CONFIG=""

if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "  Текущий Turnable URL:"
    echo "  $(cat "$CONFIG_FILE")"
    echo ""
    echo "  1) Оставить текущий URL"
    echo "  2) Заменить на новый (например, с другим кол-вом peers)"
    echo ""
    ask "  Выбери (1 или 2): "

    if [ "$REPLY" = "1" ]; then
        echo "  OK: Оставляю текущий конфиг"
        SKIP_CONFIG=1
    fi
fi

if [ -z "$SKIP_CONFIG" ]; then
    echo ""
    echo "  Вставь URL конфигурации от сервера Turnable."
    echo "  Выглядит как: turnable://uuid:call@vk.com/wg?pub_key=..."
    echo ""
    echo "  (На сервере: ./turnable config generate UUID ROUTE)"
    echo ""
    ask "  URL: "
    CONFIG_URL="$REPLY"

    if [ -z "$CONFIG_URL" ]; then
        echo "  ОШИБКА: URL не может быть пустым"
        exit 1
    fi

    case "$CONFIG_URL" in
        turnable://*) ;;
        *)
            echo "  ! URL не начинается с turnable:// — возможно ошибка"
            ask "  Продолжить? (д/н): "
            case "$REPLY" in
                д|y) ;;
                *)   exit 1 ;;
            esac
            ;;
    esac

    echo "$CONFIG_URL" > "$CONFIG_FILE"
    echo "  OK: Конфиг сохранён"
fi

# ─── Шаг 4: Создание скриптов ───
echo ""
echo "[$((STEP=4))/$TOTAL] Создание скриптов запуска..."

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

echo "  OK: start.sh, start-bg.sh, stop.sh, status.sh"

# ─── Шаг 5: Виджеты для домашнего экрана ───
echo ""
echo "[$((STEP=5))/$TOTAL] Настройка виджетов..."

mkdir -p "$HOME/.shortcuts"

cat > "$HOME/.shortcuts/VPN-ON.sh" << WONEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
${BASH_BIN} start-bg.sh
echo ""
echo "Теперь включи WireGuard в NekoBox"
am start -n moe.nb4a/.ui.MainActivity 2>/dev/null
echo ""
echo "Нажми Enter чтобы закрыть"
read < /dev/tty
WONEOF
chmod +x "$HOME/.shortcuts/VPN-ON.sh"

cat > "$HOME/.shortcuts/VPN-OFF.sh" << WOFFEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
${BASH_BIN} stop.sh
echo "Не забудь отключить NekoBox"
echo ""
echo "Нажми Enter чтобы закрыть"
read < /dev/tty
WOFFEOF
chmod +x "$HOME/.shortcuts/VPN-OFF.sh"

cat > "$HOME/.shortcuts/VPN-STATUS.sh" << WSTEOF
#!${BASH_BIN}
cd "$INSTALL_DIR"
${BASH_BIN} status.sh
echo ""
echo "Нажми Enter чтобы закрыть"
read < /dev/tty
WSTEOF
chmod +x "$HOME/.shortcuts/VPN-STATUS.sh"

echo "  OK: VPN-ON, VPN-OFF, VPN-STATUS"

# ─── Шаг 6: Автозапуск ───
echo ""
echo "[$((STEP=6))/$TOTAL] Автозапуск при включении телефона..."

echo "  Настроить автозапуск? (нужен Termux:Boot)"
ask "  (д/н): "
case "$REPLY" in
    д|y)
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
        echo "  OK: Автозапуск настроен"
        echo "  !  Открой Termux:Boot хотя бы раз"
        ;;
    *)
        echo "  OK: Пропущено"
        ;;
esac

# ─── Итог ───
echo ""
echo "========================================"
echo "  Установка завершена!"
echo "========================================"
echo ""
echo "  ~/Turnable/"
echo "  ├── turnable        — ядро"
echo "  ├── wireguard.txt   — конфиг"
echo "  ├── start.sh        — запуск (с логами)"
echo "  ├── start-bg.sh     — запуск в фоне"
echo "  ├── stop.sh         — остановка"
echo "  └── status.sh       — статус"
echo ""
echo "  Использование:"
echo "    cd ~/Turnable && bash start.sh"
echo ""
echo "  Или кнопки: VPN-ON / VPN-OFF / VPN-STATUS"
echo ""
echo "  Порядок: Turnable -> подождать -> NekoBox"
echo ""
echo "========================================"
